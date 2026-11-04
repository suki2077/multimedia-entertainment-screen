// Read-only FAT32 MUSIC.WAV stream. PCM 48kHz, signed 16-bit stereo; RIFF chunks and padding.
// Supports primary MBR FAT32 partitions and FAT32 superfloppy volumes.
// Sector interface is SDHC/SDXC block addressed; this stage targets the user's SDHC card.
module fat32_wav_stream #(
    parameter INIT_TIMEOUT=714285710, IO_TIMEOUT=35714286
)(
    input wire clk,rst,enable,sd_ready,
    input wire io_wait,
    output reg sector_req, output reg [31:0] sector_lba,
    input wire byte_valid,input wire [7:0] byte_data,input wire sector_end,
    output reg sample_valid,input wire sample_ready,
    output reg [31:0] sample_data,
    output reg done,failed,output reg [7:0] error_code,
    output wire [5:0] debug_state
);
    localparam WAIT_INIT=0,WAIT_SECTOR=1,BOOT=2,PART=3,BPB=4,GEOMETRY=5,
        ROOT_REQ=6,DIR=7,DIR_NEXT=8,FAT_REQ=9,FAT_PARSE=10,FILE_REQ=11,
        HEADER=12,STREAM=13,SEND=14,FILE_NEXT=15,FINISH=16,FAIL=17,
        ROOT_LOADED=18,BYTE_PROCESS=19,GEOMETRY_A=20,GEOMETRY_B=21,HEADER_DECIDE=22;
    reg [5:0] state,return_state;
    assign debug_state=state;
    reg [7:0] header_mem [0:63];
    reg [7:0] pixel_mem [0:511];
    reg [7:0] pixel_byte;
    reg [7:0] part_type[0:3];
    reg [31:0] part_start[0:3],part_size[0:3];
    reg [31:0] fat_entry;
    reg [2:0] wav_phase;
    reg [3:0] header_pos;
    reg [31:0] riff_size,chunk_id,chunk_size,chunk_left,chunk_pos,data_left;
    reg [127:0] fmt_data;
    reg [31:0] sample_word;
    reg fmt_ok,chunk_odd,last_sample;
    reg [63:0] riff_magic;
    reg [1:0] valid_index;
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
    reg [19:0] hops;
    reg fat_for_dir;
    reg [31:0] file_size,file_pos,pixel_offset;
    reg [18:0] pixels;
    reg [9:0] x;
    reg [20:0] row_base;
    reg top_down;
    reg [1:0] channel,group_slot;
    reg [7:0] blue,green;
    wire [8:0] mbr_relative=received[8:0]-9'd446;
    wire [31:0] cluster_sector=data_base+((cluster-2)<<spc_shift);
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
        if(state==WAIT_SECTOR && byte_valid && received<512)
            pixel_mem[received[8:0]]<=byte_data;
        pixel_byte<=pixel_mem[ptr[8:0]];
    end
    task reject;
        input [7:0] code;
        begin failed<=1;error_code<=code;state<=FAIL;sector_req<=0;sample_valid<=0;end
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
            wav_phase<=0;header_pos<=0;riff_size<=0;chunk_id<=0;chunk_size<=0;chunk_left<=0;chunk_pos<=0;data_left<=0;fmt_data<=0;sample_word<=0;fmt_ok<=0;chunk_odd<=0;last_sample<=0;riff_magic<=0;
            valid_index<=0;directory_cluster<=0;directory_sector<=0;scan_skip<=0;resume_offset<=0;header_ok<=0;
            state<=WAIT_INIT;return_state<=0;sector_req<=0;sector_lba<=0;
            received<=0;ptr<=0;watchdog<=0;partition_index<=0;
            volume_base<=0;volume_size<=0;fat_base<=0;data_base<=0;fat_size<=0;
            spc<=0;nfats<=0;active_fat<=0;spc_shift<=0;reserved<=0;
            root_cluster<=0;cluster<=0;last_cluster<=0;sector_in_cluster<=0;
            entry_offset<=0;hops<=0;fat_for_dir<=0;
            file_size<=0;file_pos<=0;pixel_offset<=0;pixels<=0;x<=0;row_base<=0;
            top_down<=0;channel<=0;group_slot<=0;blue<=0;green<=0;
            sample_valid<=0;sample_data<=0;done<=0;failed<=0;error_code<=0;
            signature<=0;fat_entry<=0;dir_name<=0;dir_first<=0;dir_attr<=0;
            overhead<=0;cluster_count<=0;
            dir_cluster_tmp<=0;dir_size_tmp<=0;found_cluster<=0;found_size<=0;dir_found<=0;dir_end<=0;
            for(i=0;i<4;i=i+1)begin part_type[i]<=0;part_start[i]<=0;part_size[i]<=0;end
        end else begin
            sector_req<=0;
            if(state==WAIT_INIT || state==WAIT_SECTOR || state==SEND) begin
                if(byte_valid || (sample_valid && sample_ready) || io_wait) watchdog<=0;
                else watchdog<=watchdog+1'b1;
            end else watchdog<=0;
            if(state==WAIT_SECTOR && byte_valid) begin
                if(received<64) header_mem[received[5:0]]<=byte_data;
                if(received==510)signature[7:0]<=byte_data;
                if(received==511)signature[15:8]<=byte_data;
                if(return_state==BOOT && received>=446 && received<510) begin
                    case(mbr_relative[3:0])
                        4:part_type[mbr_relative[5:4]]<=byte_data;
                        8:part_start[mbr_relative[5:4]][7:0]<=byte_data;
                        9:part_start[mbr_relative[5:4]][15:8]<=byte_data;
                        10:part_start[mbr_relative[5:4]][23:16]<=byte_data;
                        11:part_start[mbr_relative[5:4]][31:24]<=byte_data;
                        12:part_size[mbr_relative[5:4]][7:0]<=byte_data;
                        13:part_size[mbr_relative[5:4]][15:8]<=byte_data;
                        14:part_size[mbr_relative[5:4]][23:16]<=byte_data;
                        15:part_size[mbr_relative[5:4]][31:24]<=byte_data;
                    endcase
                end
                if(return_state==FAT_PARSE && received[8:2]==cluster[6:0])
                    fat_entry[received[1:0]*8+:8]<=byte_data;
                if(return_state==ROOT_LOADED) begin
                    if(received[4:0]<11)dir_name<={dir_name[79:0],byte_data};
                    case(received[4:0])
                        0:begin dir_first<=byte_data;if(byte_data==0)dir_end<=1;end
                        11:dir_attr<=byte_data;
                        20:dir_cluster_tmp[23:16]<=byte_data;21:dir_cluster_tmp[31:24]<=byte_data;
                        26:dir_cluster_tmp[7:0]<=byte_data;27:dir_cluster_tmp[15:8]<=byte_data;
                        28:dir_size_tmp[7:0]<=byte_data;29:dir_size_tmp[15:8]<=byte_data;
                        30:dir_size_tmp[23:16]<=byte_data;
                        31:if(received>=scan_skip && !dir_end && !dir_found && dir_first!=8'he5 &&
                              (dir_attr&8'h18)==0 && dir_attr!=8'h0f &&
                              dir_name==88'h4d55534943202020574156)begin
                            dir_found<=1;found_cluster<=dir_cluster_tmp;
                            resume_offset<={1'b0,received[8:5],5'd0}+10'd32;
                            found_size<={byte_data,dir_size_tmp[23:0]};
                        end
                    endcase
                end
                received<=received+1'b1;
            end
            case(state)
                WAIT_INIT: if(enable && sd_ready) read_sector(0,BOOT);
                WAIT_SECTOR: if(sector_end) begin
                    if(received+(byte_valid?1:0)!=512) reject(8'h02);
                    else state<=return_state;
                end
                BOOT: if(signature!=16'haa55) reject(8'h03);
                    else if(u16(11)==512 && u16(17)==0 && u16(22)==0) state<=BPB;
                    else begin partition_index<=0;state<=PART;end
                PART: if((part_type[partition_index]==8'h0b || part_type[partition_index]==8'h0c) &&
                        part_start[partition_index]!=0 && part_size[partition_index]!=0) begin
                        volume_base<=part_start[partition_index];
                        read_sector(part_start[partition_index],BPB);
                    end else if(partition_index==3) reject(8'h03);
                    else partition_index<=partition_index+1'b1;
                BPB: begin
                    if(signature!=16'haa55 || u16(11)!=512 || u16(17)!=0 || u16(22)!=0 ||
                       u16(14)==0 || header_mem[16]==0 || header_mem[16]>2 || u32(36)==0 || u32(36)>=33554432 ||
                       u16(42)!=0 || u16(19)!=0 || u32(32)==0 ||
                       (header_mem[13] & (header_mem[13]-1))!=0 || header_mem[13]==0 || header_mem[13]>128 ||
                       (header_mem[40][7] && header_mem[40][3:0]>=header_mem[16])) reject(8'h03);
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
                GEOMETRY: if(volume_size<=overhead || volume_base+volume_size<volume_base ||
                        cluster_count<65525 || cluster_count>=32'h0ffffff5 ||
                        root_cluster<2 || root_cluster>cluster_count+1 ||
                        (fat_size<<7)<cluster_count+2) reject(8'h03);
                    else begin
                        last_cluster<=cluster_count+1;
                        cluster<=root_cluster;sector_in_cluster<=0;state<=ROOT_REQ;
                    end
                ROOT_REQ: read_sector(cluster_sector+sector_in_cluster,ROOT_LOADED);
                ROOT_LOADED: if(dir_found)begin
                        directory_cluster<=cluster;directory_sector<=sector_in_cluster;
                        if(found_cluster<2 || found_cluster>last_cluster || found_size<44)
                            begin scan_skip<=resume_offset;state<=ROOT_REQ;end
                        else begin
                            cluster<=found_cluster;file_size<=found_size;
                            sector_in_cluster<=0;file_pos<=0;ptr<=0;
                            read_sector(data_base+((found_cluster-2)<<spc_shift),HEADER);
                        end
                    end else if(dir_end)reject(8'h04);else state<=DIR_NEXT;
                DIR_NEXT: begin
                    scan_skip<=0;
                    if(sector_in_cluster+1<spc) begin
                        sector_in_cluster<=sector_in_cluster+1'b1;state<=ROOT_REQ;
                    end else begin fat_for_dir<=1;state<=FAT_REQ;end
                end
                FAT_REQ: if(hops==1048575 || (fat_for_dir && hops>=8191)) reject(8'h08);
                    else begin hops<=hops+1'b1;read_sector(fat_base+(cluster>>7),FAT_PARSE);end
                FAT_PARSE: if(fat_value>=32'h0ffffff8) begin
                        if(fat_for_dir) reject(8'h04);else reject(8'h07);
                    end else if(fat_value<2 || fat_value>last_cluster || fat_value==cluster)
                        reject(8'h05);
                    else begin
                        cluster<=fat_value;sector_in_cluster<=0;
                        if(fat_for_dir) state<=ROOT_REQ;
                        else read_sector(data_base+((fat_value-2)<<spc_shift),STREAM);
                    end
                HEADER: begin
                    ptr<=0;file_pos<=0;wav_phase<=0;header_pos<=0;fmt_ok<=0;state<=STREAM;
                end
                STREAM: if(ptr==512)state<=FILE_NEXT;
                    else if(file_pos>=file_size)reject(8'h07);
                    else state<=BYTE_PROCESS;
                BYTE_PROCESS: begin
                    ptr<=ptr+1'b1;file_pos<=file_pos+1'b1;state<=STREAM;
                    case(wav_phase)
                        0:begin
                            if(header_pos<4 || header_pos>=8)riff_magic<={riff_magic[55:0],pixel_byte};
                            if(header_pos>=4 && header_pos<8)riff_size[(header_pos-4)*8+:8]<=pixel_byte;
                            if(header_pos==11)begin
                                if({riff_magic[55:0],pixel_byte}!=64'h5249464657415645 || riff_size<36 || riff_size>file_size-8)reject(8'h06);
                                else begin wav_phase<=1;header_pos<=0;chunk_id<=0;chunk_size<=0;end
                            end else header_pos<=header_pos+1'b1;
                        end
                        1:begin
                            if(header_pos<4)chunk_id<={chunk_id[23:0],pixel_byte};
                            else chunk_size[(header_pos-4)*8+:8]<=pixel_byte;
                            if(header_pos==7)begin
                                header_pos<=0;chunk_pos<=0;chunk_left<={pixel_byte,chunk_size[23:0]};chunk_odd<=chunk_size[0];
                                if({pixel_byte,chunk_size[23:0]}>file_size-file_pos-1 || file_pos>=riff_size+8)reject(8'h06);
                                else if(chunk_id==32'h666d7420)begin
                                    if({pixel_byte,chunk_size[23:0]}<16)reject(8'h06);
                                    else begin wav_phase<=2;fmt_data<=0;end
                                end else if(chunk_id==32'h64617461)begin
                                    if(!fmt_ok || {pixel_byte,chunk_size[23:0]}==0 || chunk_size[1:0]!=0)reject(8'h06);
                                    else begin data_left<={pixel_byte,chunk_size[23:0]};wav_phase<=4;channel<=0;end
                                end else if({pixel_byte,chunk_size[23:0]}==0)begin chunk_id<=0;chunk_size<=0;end
                                else wav_phase<=3;
                            end else header_pos<=header_pos+1'b1;
                        end
                        2:begin
                            if(chunk_pos<16)fmt_data[chunk_pos[3:0]*8+:8]<=pixel_byte;
                            if(chunk_pos==15)begin
                                if(fmt_data[15:0]!=1 || fmt_data[31:16]!=2 || fmt_data[63:32]!=48000 ||
                                    fmt_data[95:64]!=192000 || fmt_data[111:96]!=4 || fmt_data[119:112]!=16 || pixel_byte!=0)reject(8'h06);
                                else fmt_ok<=1;
                            end
                            chunk_pos<=chunk_pos+1'b1;chunk_left<=chunk_left-1'b1;
                            if(chunk_left==1)begin wav_phase<=chunk_odd?5:1;header_pos<=0;chunk_id<=0;chunk_size<=0;end
                        end
                        3:begin
                            chunk_left<=chunk_left-1'b1;
                            if(chunk_left==1)begin wav_phase<=chunk_odd?5:1;header_pos<=0;chunk_id<=0;chunk_size<=0;end
                        end
                        4:begin
                            sample_word[channel*8+:8]<=pixel_byte;data_left<=data_left-1'b1;
                            if(channel==3)begin
                                sample_data<={pixel_byte,sample_word[23:0]};sample_valid<=1;last_sample<=(data_left==1);
                                channel<=0;state<=SEND;
                            end else channel<=channel+1'b1;
                        end
                        5:begin wav_phase<=1;header_pos<=0;chunk_id<=0;chunk_size<=0;end
                        default:reject(8'h06);
                    endcase
                end
                SEND:if(sample_valid && sample_ready)begin
                    sample_valid<=0;if(last_sample)begin done<=1;state<=FINISH;end else state<=STREAM;
                end
                FILE_NEXT: begin
                    ptr<=0;
                    if(sector_in_cluster+1<spc) begin
                        sector_in_cluster<=sector_in_cluster+1'b1;
                        read_sector(cluster_sector+sector_in_cluster+1,STREAM);
                    end else begin fat_for_dir<=0;state<=FAT_REQ;end
                end
                FINISH: state<=FINISH;
                FAIL: state<=FAIL;
                default: reject(8'h09);
            endcase
            if(state==WAIT_INIT && watchdog>=INIT_TIMEOUT) reject(8'h01);
            else if((state==WAIT_SECTOR || state==SEND) && watchdog>=IO_TIMEOUT) reject(8'h02);
        end
    end
endmodule

