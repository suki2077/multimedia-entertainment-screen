// Read-only FAT32 root scan: select one of the first twenty valid BMP files (parameterized index width), in directory order.
// Supports primary MBR FAT32 partitions and FAT32 superfloppy volumes.
// Sector interface is SDHC/SDXC block addressed; this stage targets the user's SDHC card.
module fat32_bmp_loader #(
    parameter INIT_TIMEOUT=714285710, IO_TIMEOUT=35714286, INDEX_BITS=2, CATALOG=0
)(
    input wire clk,rst,enable,sd_ready,io_wait,
    input wire [INDEX_BITS-1:0] image_index,
    output reg sector_req, output reg [31:0] sector_lba,
    input wire byte_valid,input wire [7:0] byte_data,input wire sector_end,
    output wire group_valid,input wire group_ready,
    output wire [20:0] group_addr,output wire [127:0] group_data,
    output reg done,failed,output reg [7:0] error_code,
    input wire scan_only,output reg scan_done,output reg [4:0] image_count,
    output wire [5:0] debug_state
);
    // Register the complete incoming event bundle before header/FAT decoding.
    // This also breaks the ownership/reset -> arbiter -> header write-enable path.
    reg rx_valid,rx_end;reg [7:0] rx_data;
    always @(posedge clk or posedge rst)begin
      if(rst)begin rx_valid<=0;rx_end<=0;rx_data<=0;end
      else begin rx_valid<=byte_valid;rx_end<=sector_end;rx_data<=byte_data;end
    end
    localparam WAIT_INIT=0,WAIT_SECTOR=1,BOOT=2,PART=3,BPB=4,GEOMETRY=5,
        ROOT_REQ=6,DIR=7,DIR_NEXT=8,FAT_REQ=9,FAT_PARSE=10,FILE_REQ=11,
        HEADER=12,STREAM=13,SEND=14,FILE_NEXT=15,FINISH=16,FAIL=17,
        ROOT_LOADED=18,BYTE_PROCESS=19,GEOMETRY_A=20,GEOMETRY_B=21,HEADER_DECIDE=22,HEADER_SIZE=23,HEADER_CHECK=24,RAW_SEND=25,READER_DONE=26,PART_LATCH=27;
    localparam BPB_CHECK=11,GEOMETRY_CHECK=27,ROOT_VALIDATE=32;reg bpb_bad,geometry_bad,root_file_bad;
    reg [5:0] state,return_state;
    assign debug_state=state;
    reg [7:0] header_mem [0:63];
    reg [7:0] pixel_mem [0:511];
    reg [7:0] pixel_byte;
    reg [7:0] part_type_temp;
    reg [31:0] part_lba_temp,chosen_partition;
    reg [23:0] part_size_temp;
    reg partition_found;
    reg [31:0] fat_entry;
    reg [INDEX_BITS-1:0] valid_index;
    reg [31:0] directory_cluster;
    reg [7:0] directory_sector;
    reg [9:0] scan_skip,resume_offset;
    reg header_ok;
    reg [87:0] dir_name;
    reg [7:0] dir_first,dir_attr;
    reg [31:0] dir_cluster_tmp,dir_size_tmp;
    reg [31:0] found_cluster,found_size;
    reg dir_found,dir_end;
    reg [9:0] received,ptr;
    reg [31:0] watchdog;
    reg [1:0] partition_index;
    reg [31:0] volume_base,volume_size,fat_base,data_base,fat_size;
    reg [7:0] spc,nfats,active_fat;
    reg [2:0] spc_shift;
    reg [15:0] reserved;
    reg [31:0] root_cluster,cluster,last_cluster;
    reg [7:0] sector_in_cluster;
    reg [8:0] entry_offset;
    reg [16:0] hops;
    reg[7:0] selected_type;reg[31:0] selected_start,selected_size;
    reg fat_for_dir;
    reg [31:0] file_size,file_pos,pixel_offset;
    reg [12:0] source_w,source_h;
    reg [11:0] source_x;
    reg [12:0] source_y;
    reg [1:0] padding_left;
    reg [26:0] payload;
    reg [31:0] payload_end,payload_available;reg payload_bad;
    localparam HEADER_BOUNDS=14,HEADER_VALIDATE=7;
    reg [13:0] stride;
    reg top_down;
    reg [1:0] channel;
    reg [7:0] blue,green;
    reg raw_valid,scaler_start;
    reg [23:0] raw_rgb;
    wire raw_ready,scaler_done,scaler_failed;
    bmp_fit_scaler u_scaler(.clk(clk),.rst(rst|failed),.start(scaler_start),
      .width(source_w),.height(source_h),.top_down(top_down),
      .raw_valid(raw_valid),.raw_rgb(raw_rgb),.raw_ready(raw_ready),
      .group_valid(group_valid),.group_ready(group_ready),.group_addr(group_addr),.group_data(group_data),
      .done(scaler_done),.failed(scaler_failed));
    wire [8:0] mbr_relative=received[8:0]-9'd446;
    reg [31:0] cluster_sub,cluster_shift,cluster_sector;
    reg [2:0] cluster_wait;
    reg [31:0] next_fat,next_sub,next_offset,next_lba;
    reg fat_eoc,fat_invalid;
    localparam OPEN_FILE=28,FAT_SHIFT=29,FAT_ADDR=30,FAT_DECIDE=31;
    always @(posedge clk or posedge rst)begin
      if(rst)begin cluster_sub<=0;cluster_shift<=0;cluster_sector<=0;cluster_wait<=0;end
      else begin
       cluster_sub<=cluster-2;cluster_shift<=cluster_sub<<spc_shift;cluster_sector<=data_base+cluster_shift;
       if(state==ROOT_REQ || state==OPEN_FILE)begin if(cluster_wait<4)cluster_wait<=cluster_wait+1'b1;end
       else cluster_wait<=0;
      end
    end
    function [15:0] u16;
        input [8:0] a;
        begin u16={header_mem[a+9'd1],header_mem[a]};end
    endfunction
    function [31:0] u32;
        input [8:0] a;
        begin u32={header_mem[a+9'd3],header_mem[a+9'd2],header_mem[a+9'd1],header_mem[a]};end
    endfunction
    wire [31:0] fat_value={4'd0,fat_entry[27:0]};
    reg [31:0] overhead,cluster_count;
    reg [15:0] signature;
    integer i;
    // One write and one synchronous read port: maps to RAM, not a 512-way mux.
    always @(posedge clk) begin
        if(state==WAIT_SECTOR && rx_valid && received<512)
            pixel_mem[received[8:0]]<=rx_data;
        pixel_byte<=pixel_mem[ptr[8:0]];
    end
    // Header bytes are scratch storage, like the sector RAM: they do not
    // need reset. Keep reset out of the large indexed write-enable decoder.
    reg header_we_q;reg [5:0] header_addr_q;reg [7:0] header_byte_q;
    always @(posedge clk)begin
      header_we_q<=state==WAIT_SECTOR && rx_valid && received<64;
      header_addr_q<=received[5:0];header_byte_q<=rx_data;
      if(header_we_q)header_mem[header_addr_q]<=header_byte_q;
    end
    task reject;
        input [7:0] code;
        begin failed<=1;error_code<=code;state<=FAIL;sector_req<=0;raw_valid<=0;end
    endtask
    task directory_end;
        begin
            if(CATALOG && scan_only)begin image_count<=valid_index;scan_done<=1;state<=FINISH;end
            else reject(8'h04);
        end
    endtask
    task resume_directory;
        begin cluster<=directory_cluster;sector_in_cluster<=directory_sector;
            scan_skip<=resume_offset;state<=ROOT_REQ;end
    endtask
    task read_sector;
        input [31:0] lba; input [5:0] after_read;
        begin sector_lba<=lba;sector_req<=1;received<=0;
            signature<=0;
            if(after_read==ROOT_LOADED) begin dir_found<=0;dir_end<=0;end
            if(after_read==FAT_PARSE) fat_entry<=0;
            return_state<=after_read;state<=WAIT_SECTOR;end
    endtask
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            scan_done<=0;image_count<=0;valid_index<=0;directory_cluster<=0;directory_sector<=0;scan_skip<=0;resume_offset<=0;header_ok<=0;
            state<=WAIT_INIT;bpb_bad<=1;root_file_bad<=1;return_state<=0;sector_req<=0;sector_lba<=0;
            next_fat<=0;next_sub<=0;next_offset<=0;next_lba<=0;fat_eoc<=0;fat_invalid<=0;
            received<=0;ptr<=0;watchdog<=0;partition_index<=0;
            volume_base<=0;volume_size<=0;fat_base<=0;data_base<=0;fat_size<=0;
            spc<=0;nfats<=0;active_fat<=0;spc_shift<=0;reserved<=0;
            root_cluster<=0;cluster<=0;last_cluster<=0;sector_in_cluster<=0;
            entry_offset<=0;hops<=0;fat_for_dir<=0;
            file_size<=0;file_pos<=0;pixel_offset<=0;source_w<=0;source_h<=0;source_x<=0;source_y<=0;
            padding_left<=0;payload<=0;payload_end<=0;payload_available<=0;payload_bad<=0;stride<=0;selected_type<=0;selected_start<=0;selected_size<=0;
            top_down<=0;channel<=0;blue<=0;green<=0;raw_valid<=0;scaler_start<=0;raw_rgb<=0;
            done<=0;failed<=0;error_code<=0;
            signature<=0;fat_entry<=0;dir_name<=0;dir_first<=0;dir_attr<=0;
            overhead<=0;cluster_count<=0;
            dir_cluster_tmp<=0;dir_size_tmp<=0;found_cluster<=0;found_size<=0;dir_found<=0;dir_end<=0;
            part_type_temp<=0;part_lba_temp<=0;part_size_temp<=0;chosen_partition<=0;partition_found<=0;
        end else begin
            sector_req<=0;scaler_start<=0;
            if(state==WAIT_INIT || state==WAIT_SECTOR || state==RAW_SEND || state==READER_DONE) begin
                if(rx_valid || (group_valid && group_ready) || (raw_valid && raw_ready) || io_wait) watchdog<=0;
                else watchdog<=watchdog+1'b1;
            end else watchdog<=0;
            if(state==WAIT_SECTOR && rx_valid) begin

                if(received==510)signature[7:0]<=rx_data;
                if(received==511)signature[15:8]<=rx_data;
                if(return_state==BOOT && received>=446 && received<510) begin
                    case(mbr_relative[3:0])
                        4:part_type_temp<=rx_data;
                        8:part_lba_temp[7:0]<=rx_data;
                        9:part_lba_temp[15:8]<=rx_data;
                        10:part_lba_temp[23:16]<=rx_data;
                        11:part_lba_temp[31:24]<=rx_data;
                        12:part_size_temp[7:0]<=rx_data;
                        13:part_size_temp[15:8]<=rx_data;
                        14:part_size_temp[23:16]<=rx_data;
                        15:if(!partition_found && (part_type_temp==8'h0b || part_type_temp==8'h0c) &&
                            part_lba_temp!=0 && {rx_data,part_size_temp}!=0)begin
                             chosen_partition<=part_lba_temp;partition_found<=1;
                           end
                    endcase
                end
                if(return_state==FAT_PARSE && received[8:2]==cluster[6:0])
                    fat_entry[received[1:0]*8+:8]<=rx_data;
                if(return_state==ROOT_LOADED) begin
                    if(received[4:0]<11)dir_name<={dir_name[79:0],rx_data};
                    case(received[4:0])
                        0:begin dir_first<=rx_data;if(rx_data==0)dir_end<=1;end
                        11:dir_attr<=rx_data;
                        20:dir_cluster_tmp[23:16]<=rx_data;21:dir_cluster_tmp[31:24]<=rx_data;
                        26:dir_cluster_tmp[7:0]<=rx_data;27:dir_cluster_tmp[15:8]<=rx_data;
                        28:dir_size_tmp[7:0]<=rx_data;29:dir_size_tmp[15:8]<=rx_data;
                        30:dir_size_tmp[23:16]<=rx_data;
                        31:if(received>=scan_skip && !dir_end && !dir_found && dir_first!=8'he5 &&
                              (dir_attr&8'h18)==0 && dir_attr!=8'h0f &&
                              ((dir_name[23:0] | 24'h202020)==24'h626d70))begin
                            dir_found<=1;found_cluster<=dir_cluster_tmp;
                            resume_offset<={1'b0,received[8:5],5'd0}+10'd32;
                            found_size<={rx_data,dir_size_tmp[23:0]};
                        end
                    endcase
                end
                received<=received+1'b1;
            end
            case(state)
                WAIT_INIT: if(enable && sd_ready) read_sector(0,BOOT);
                WAIT_SECTOR: if(rx_end) begin
                    if(rx_valid ? received!=10'd511 : received!=10'd512) reject(8'h02);
                    else state<=return_state;
                end
                BOOT: if(signature!=16'haa55) reject(8'h03);
                    else if(u16(11)==512 && u16(17)==0 && u16(22)==0) state<=BPB_CHECK;
                    else begin partition_index<=0;state<=PART;end
                PART: if(partition_found)begin
                        volume_base<=chosen_partition;read_sector(chosen_partition,BPB_CHECK);
                    end else reject(8'h03);
                BPB_CHECK:begin bpb_bad<=(signature!=16'haa55 || u16(11)!=512 || u16(17)!=0 || u16(22)!=0 ||
                       u16(14)==0 || header_mem[16]==0 || header_mem[16]>2 || u32(36)==0 || u32(36)>=33554432 ||
                       u16(42)!=0 || u16(19)!=0 || u32(32)==0 ||
                       (header_mem[13] & (header_mem[13]-8'd1))!=0 || header_mem[13]==0 || header_mem[13]>128 ||
                       (header_mem[40][7] && header_mem[40][3:0]>=header_mem[16]));state<=BPB;end
                BPB: begin
                    if(bpb_bad) reject(8'h03);
                    else begin
                        reserved<=u16(14);spc<=header_mem[13];nfats<=header_mem[16];fat_size<=u32(36);
                        volume_size<=u32(32);root_cluster<=u32(44)&32'h0fffffff;
                        active_fat<=header_mem[40][7]?{4'd0,header_mem[40][3:0]}:8'd0;
                        case(header_mem[13])
                            1:spc_shift<=0;2:spc_shift<=1;4:spc_shift<=2;8:spc_shift<=3;
                            16:spc_shift<=4;32:spc_shift<=5;64:spc_shift<=6;128:spc_shift<=7;
                        endcase
                        state<=GEOMETRY_A;
                    end
                end
                GEOMETRY_A: begin
                    overhead<={16'd0,reserved}+((nfats==2)?(fat_size<<1):fat_size);
                    fat_base<=volume_base+reserved;state<=GEOMETRY_B;
                end
                GEOMETRY_B: begin
                    cluster_count<=(volume_size-overhead)>>spc_shift;
                    data_base<=volume_base+overhead;
                    fat_base<=fat_base+((active_fat==0)?32'd0:fat_size);
                    state<=GEOMETRY;
                end
                GEOMETRY:begin geometry_bad<=(volume_size<=overhead || volume_base+volume_size<volume_base ||
                        cluster_count<65525 || cluster_count>=32'h0ffffff5 ||
                        root_cluster<2 || root_cluster>cluster_count+1 ||
                        (fat_size<<7)<cluster_count+2);state<=GEOMETRY_CHECK;end
                GEOMETRY_CHECK:if(geometry_bad)reject(8'h03);
                    else begin
                        last_cluster<=cluster_count+1;
                        cluster<=root_cluster;sector_in_cluster<=0;state<=ROOT_REQ;
                    end
                ROOT_REQ:if(cluster_wait==4)read_sector(cluster_sector+sector_in_cluster,ROOT_LOADED);
                OPEN_FILE:if(cluster_wait==4)read_sector(cluster_sector,HEADER);
                ROOT_LOADED: if(dir_found)begin
                        directory_cluster<=cluster;directory_sector<=sector_in_cluster;
                        root_file_bad<=found_cluster<2 || found_cluster>last_cluster || found_size<54;
                        state<=ROOT_VALIDATE;
                    end else if(dir_end)directory_end();else state<=DIR_NEXT;
                ROOT_VALIDATE: if(root_file_bad)begin scan_skip<=resume_offset;state<=ROOT_REQ;end
                    else begin
                        cluster<=found_cluster;file_size<=found_size;
                        sector_in_cluster<=0;file_pos<=0;ptr<=0;state<=OPEN_FILE;
                    end
                DIR_NEXT: begin
                    scan_skip<=0;
                    if(sector_in_cluster+1<spc) begin
                        sector_in_cluster<=sector_in_cluster+1'b1;state<=ROOT_REQ;
                    end else begin fat_for_dir<=1;state<=FAT_REQ;end
                end
                FAT_REQ: if(hops==131071) reject(8'h08);
                    else begin hops<=hops+1'b1;read_sector(fat_base+(cluster>>7),FAT_PARSE);end
                FAT_PARSE:begin
                    next_fat<=fat_value;next_sub<=fat_value-2;
                    fat_eoc<=fat_value>=32'h0ffffff8;
                    fat_invalid<=fat_value<2 || fat_value>last_cluster || fat_value==cluster;
                    state<=FAT_SHIFT;
                end
                FAT_SHIFT:begin next_offset<=next_sub<<spc_shift;state<=FAT_ADDR;end
                FAT_ADDR:begin next_lba<=data_base+next_offset;state<=FAT_DECIDE;end
                FAT_DECIDE:if(fat_eoc)begin
                     if(fat_for_dir)directory_end();else reject(8'h07);
                   end else if(fat_invalid)reject(8'h05);
                   else begin cluster<=next_fat;sector_in_cluster<=0;
                    if(fat_for_dir)state<=ROOT_REQ;else read_sector(next_lba,STREAM);
                   end
                HEADER: begin
                    header_ok<=!(u16(0)!=16'h4d42 || u32(14)<40 || u32(14)>1048576 ||
                        u32(18)==0 || u32(18)>4096 || u32(22)==0 ||
                        (!header_mem[25][7] && u32(22)>4096) ||
                        (header_mem[25][7] && u32(22)<32'hfffff000) ||
                        u16(26)!=1 || u16(28)!=24 || u32(30)!=0 ||
                        u32(10)<u32(14)+14 || u32(10)>file_size || u32(2)>file_size);
                    source_w<=u32(18);source_h<=header_mem[25][7]?(~u32(22)+32'd1):u32(22);
                    pixel_offset<=u32(10);top_down<=header_mem[25][7];state<=HEADER_SIZE;
                end
                HEADER_SIZE:begin
                    stride<=source_w*14'd3+{12'd0,source_w[1:0]};state<=HEADER_CHECK;
                end
                HEADER_CHECK:begin payload<=stride*source_h;state<=HEADER_BOUNDS;end
                HEADER_BOUNDS:begin payload_end<=pixel_offset+payload;payload_available<=file_size-pixel_offset;state<=HEADER_VALIDATE;end
                HEADER_VALIDATE:begin payload_bad<=payload>payload_available || u32(2)<payload_end;state<=HEADER_DECIDE;end
                HEADER_DECIDE: if(!header_ok || payload_bad) resume_directory();
                    else if(CATALOG && scan_only)begin
                        image_count<=valid_index+1'b1;
                        if(valid_index==19)begin scan_done<=1;state<=FINISH;end
                        else begin valid_index<=valid_index+1'b1;resume_directory();end
                    end
                    else if(CATALOG && valid_index==19 && image_index!=19)reject(8'h04);
                    else if(valid_index!=image_index) begin valid_index<=valid_index+1'b1;resume_directory();end
                    else begin
                        ptr<=0;file_pos<=0;source_x<=0;source_y<=0;channel<=0;padding_left<=0;
                        scaler_start<=1;state<=STREAM;
                    end
                STREAM: if(ptr==512) state<=FILE_NEXT;
                    else if(file_pos>=file_size) reject(8'h07);
                    else state<=BYTE_PROCESS;
                BYTE_PROCESS: begin
                    state<=STREAM;ptr<=ptr+1'b1;file_pos<=file_pos+1'b1;
                    if(file_pos>=pixel_offset)begin
                        if(padding_left!=0)begin
                            padding_left<=padding_left-1'b1;
                            if(source_y==source_h && padding_left==1)state<=READER_DONE;
                        end
                        else case(channel)
                            0:begin blue<=pixel_byte;channel<=1;end
                            1:begin green<=pixel_byte;channel<=2;end
                            2:begin
                                raw_rgb<={pixel_byte,green,blue};raw_valid<=1;channel<=0;state<=RAW_SEND;
                                if({1'b0,source_x}+13'd1==source_w)begin
                                    source_x<=0;source_y<=source_y+1'b1;padding_left<=source_w[1:0];
                                end else source_x<=source_x+1'b1;
                            end
                        endcase
                    end
                end
                RAW_SEND:if(raw_ready)begin
                    raw_valid<=0;
                    if(source_y==source_h && padding_left==0)state<=READER_DONE;else state<=STREAM;
                end
                READER_DONE:if(scaler_done)begin done<=1;state<=FINISH;end
                FILE_NEXT: begin
                    ptr<=0;
                    if(sector_in_cluster+1<spc) begin
                        sector_in_cluster<=sector_in_cluster+1'b1;
                        read_sector(cluster_sector+{24'd0,(sector_in_cluster+8'd1)},STREAM);
                    end else begin fat_for_dir<=0;state<=FAT_REQ;end
                end
                FINISH: state<=FINISH;
                FAIL: state<=FAIL;
                default: reject(8'h09);
            endcase
            if(scaler_failed && !failed)reject(8'h09);
            if(state==WAIT_INIT && watchdog>=INIT_TIMEOUT) reject(8'h01);
            else if((state==WAIT_SECTOR || state==RAW_SEND || state==READER_DONE) && watchdog>=IO_TIMEOUT) reject(8'h02);
        end
    end
endmodule

