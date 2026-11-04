// Two frame buffers: background aligned writes, priority line reads, row-zero commit.
module frame_store_bmp #(
    parameter WATCHDOG_LIMIT=71428571
)(
    input wire clk,rst,init_done,refresh_busy,
    input wire group_valid,output wire group_ready,
    input wire [20:0] group_addr,input wire [127:0] group_data,
    input wire load_done,load_failed,begin_load,swap_allowed,output wire frame_pending,input wire [1:0] image_index,
    output reg swapped,output reg [1:0] displayed,
    output wire wr_en,output wire [20:0] wr_addr,output wire [31:0] wr_data,
    output wire rd_en,output wire [20:0] rd_addr,
    input wire rd_valid,input wire [31:0] rd_data,
    input wire line_req_toggle,input wire [8:0] line_req_row,
    output reg line_ack_toggle,
    output wire line_we,output wire [10:0] line_waddr,output wire [23:0] line_wdata,
    output reg [8:0] tag_even,tag_odd,output reg valid_even,valid_odd,
    output reg committed,ready,failed
);
    localparam LOAD=0,WRITE=1,GAP=2,LSTART=3,LINE=4,IDLE=5,FAIL=6;
    reg [2:0] state;
    reg [20:0] write_base,display_base,back_base,line_base;
    reg pending,loading;
    reg allow_meta,allow_sync;
    assign frame_pending=pending && ready;
    always @(posedge clk or posedge rst)begin
        if(rst)begin allow_meta<=0;allow_sync<=0;end
        else begin allow_meta<=swap_allowed;allow_sync<=allow_meta;end
    end
    reg [127:0] write_words;
    reg [1:0] word_index;
    reg [18:0] written;
    reg [5:0] gap;
    reg [9:0] issued,received;
    reg [8:0] target_row;
    reg pending_token,req_meta,req_sync;
    reg [26:0] watchdog;
    reg rvalid;
    reg [31:0] rdata;
    assign group_ready=(state==LOAD)&&init_done&&!refresh_busy&&!load_failed&&loading&&!pending&&!begin_load&&written<307200&&(req_sync==line_ack_toggle || !ready);
    assign wr_en=(state==WRITE);
    assign wr_addr=write_base+word_index;
    assign wr_data=write_words[word_index*32+:32];
    assign rd_en=(state==LINE)&&(issued<640);
    assign rd_addr=line_base+issued;
    assign line_we=(state==LINE)&&rvalid;
    assign line_waddr={target_row[0],received};
    assign line_wdata=rdata[23:0];
    always @(posedge clk or posedge rst) begin
        if(rst) begin req_meta<=0;req_sync<=0;rvalid<=0;rdata<=0;end
        else begin req_meta<=line_req_toggle;req_sync<=req_meta;
            rvalid<=rd_valid;rdata<=rd_data;end
    end
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=LOAD;display_base<=0;back_base<=0;line_base<=0;pending<=0;loading<=1;swapped<=0;displayed<=0;write_base<=0;write_words<=0;word_index<=0;written<=0;
            gap<=0;issued<=0;received<=0;target_row<=0;pending_token<=0;
            line_ack_toggle<=0;tag_even<=0;tag_odd<=0;valid_even<=0;valid_odd<=0;
            committed<=0;ready<=0;failed<=0;watchdog<=0;
        end else begin
            swapped<=0;
            if(begin_load) begin written<=0;pending<=0;loading<=1;back_base<=ready ? (display_base==0 ? 21'd307200 : 21'd0) : 21'd0;end
            if(load_failed) begin loading<=0;pending<=0;end
            if(state==LOAD || state==IDLE || state==FAIL || rd_en || wr_en || rvalid)
                watchdog<=0;
            else watchdog<=watchdog+1'b1;
            case(state)
                LOAD: begin
                    if(ready && req_sync!=line_ack_toggle) begin
                        target_row<=line_req_row;pending_token<=req_sync;gap<=0;
                        line_base<=display_base;
                        state<=LSTART;
                    end else if(!ready && pending) begin
                        display_base<=back_base;line_base<=back_base;target_row<=0;
                        pending_token<=req_sync;gap<=0;pending<=0;loading<=0;
                        displayed<=image_index;swapped<=1;committed<=1;state<=LSTART;
                    end else if(written==307200 && load_done && loading) pending<=1;
                    else if(group_valid && group_ready) begin
                        if(group_addr[1:0]!=0 || group_addr>307196) begin failed<=1;state<=FAIL;end
                        else begin write_base<=back_base+group_addr;write_words<=group_data;word_index<=0;state<=WRITE;end
                    end
                end
                WRITE: begin written<=written+1'b1;
                    if(word_index==3) begin gap<=0;state<=GAP;end
                    else word_index<=word_index+1'b1;
                end
                GAP: if(gap==31) state<=LOAD;
                    else gap<=gap+1'b1;
                LSTART: if(gap<31) begin gap<=gap+1'b1;if(gap==0) begin
                        if(pending && target_row==0 && allow_sync) begin
                            display_base<=back_base;line_base<=back_base;displayed<=image_index;
                            pending<=0;loading<=0;swapped<=1;
                        end else line_base<=line_base+target_row*21'd640;
                    end end
                    else if(!refresh_busy) begin issued<=0;received<=0;state<=LINE;end
                LINE: begin
                    if(rd_en) issued<=issued+1'b1;
                    if(rvalid) begin
                        received<=received+1'b1;
                        if(received==639) begin
                            if(target_row[0]) begin tag_odd<=target_row;valid_odd<=1;end
                            else begin tag_even<=target_row;valid_even<=1;end
                            line_ack_toggle<=pending_token;ready<=1;state<=LOAD;
                        end
                    end
                end
                IDLE: if(req_sync!=line_ack_toggle) begin
                    target_row<=line_req_row;pending_token<=req_sync;gap<=0;state<=LSTART;
                end
                default: state<=FAIL;
            endcase
            if(state!=FAIL && watchdog>=WATCHDOG_LIMIT) begin
                failed<=1;ready<=0;state<=FAIL;
            end
        end
    end
endmodule

