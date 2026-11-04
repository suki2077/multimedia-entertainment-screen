// 480x270 packed RGB565, four SDRAM slots. Full 640x480 panel mapping; no generated black bands.
// Frame switches occur only while fetching row zero during vertical blanking.
module video_store(
 input wire clk,rst,init_done,refresh_busy,paused,source_toggle,
 input wire sample_valid,input wire [31:0] sample_data,output wire sample_ready,
 output wire wr_en,output wire [20:0] wr_addr,output wire [31:0] wr_data,
 output wire rd_en,output wire [20:0] rd_addr,input wire rd_valid,input wire [31:0] rd_data,
 input wire line_req_toggle,input wire [8:0] line_req_row,output reg line_ack_toggle,
 output wire line_we,output wire [10:0] line_waddr,output wire [31:0] line_wdata,
 output reg [8:0] tag_even,tag_odd,output reg valid_even,valid_odd,
 output reg ready,output reg [31:0] displayed_frames,output reg [31:0] late_frames,output wire frame_pending);
 localparam IDLE=0,WRITE=1,GAP=2,LSTART=3,LINE=4;
 reg [2:0] state;
 reg [1:0] display_bank,write_bank;
 reg [1:0] queued;
 reg [1:0] input_word;
 reg [127:0] words;
 reg [16:0] written,write_offset;
 reg [1:0] wi;
 reg [2:0] due;reg source_meta,source_sync,source_seen;
 reg [5:0] gap;
 reg [8:0] target_row;
 reg [8:0] issued,received;
 reg [20:0] line_base;
 reg req_meta,req_sync,token;
 reg [8:0] row_meta,row_sync;
 reg black_line;
 wire [12:0] row_times_nine={target_row,3'b0}+{3'b0,target_row};
 wire [8:0] native_row=row_times_nine[12:4];
 reg rvalid;reg [31:0] rdata;
 function [31:0] expand;input [15:0] p;
  begin expand={8'd0,p[15:11],p[15:13],p[10:5],p[10:9],p[4:0],p[4:2]};end
 endfunction
 function [20:0] bank_base;input [1:0] bank;
  begin case(bank)0:bank_base=1228800;1:bank_base=1293600;2:bank_base=1358400;default:bank_base=1423200;endcase end
 endfunction
 wire pending=queued!=0;
 wire first_frame_buffered=queued>=2;
 wire completing=state==WRITE && wi==3 && written==64799;
 wire taking=state==LSTART && gap==0 && pending &&
             (!ready || (target_row==0 && !paused && due!=0));
 assign frame_pending=pending;
 wire source_event=source_sync!=source_seen;
 wire committing=state==LSTART && gap==0 && ready && target_row==0 && !paused && due!=0 && pending;
 wire request_line=ready && req_sync!=line_ack_toggle;
 // Initial display startup also takes the IDLE slot. Do not acknowledge a
 // producer word in that cycle: the line-start branch does not capture it.
 assign sample_ready=state==IDLE && init_done && !refresh_busy && queued<3 && !request_line &&
                     (ready || !first_frame_buffered);
 assign wr_en=state==WRITE;
 assign wr_addr=bank_base(write_bank)+write_offset+wi;
 assign wr_data=words[wi*32+:32];
 assign rd_en=state==LINE && issued<240 && !black_line;
 assign rd_addr=line_base+issued;
 assign line_we=state==LINE && (black_line || rvalid);
 assign line_waddr={target_row[0],1'b0,received};
 assign line_wdata=black_line?32'd0:rdata;
 always @(posedge clk or posedge rst)begin
  if(rst)begin req_meta<=0;req_sync<=0;row_meta<=0;row_sync<=0;rvalid<=0;rdata<=0;end
  else begin req_meta<=line_req_toggle;req_sync<=req_meta;row_meta<=line_req_row;row_sync<=row_meta;rvalid<=rd_valid;rdata<=rd_data;end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;display_bank<=0;write_bank<=1;queued<=0;input_word<=0;words<=0;
   written<=0;write_offset<=0;wi<=0;due<=0;source_meta<=0;source_sync<=0;source_seen<=0;gap<=0;target_row<=0;issued<=0;received<=0;
   line_base<=0;black_line<=1;token<=0;line_ack_toggle<=0;tag_even<=0;tag_odd<=0;valid_even<=0;valid_odd<=0;
   ready<=0;displayed_frames<=0;late_frames<=0;
  end else begin
   source_meta<=source_toggle;source_sync<=source_meta;source_seen<=source_sync;
   case({completing,taking})
    2'b10:queued<=queued+1'b1;
    2'b01:queued<=queued-1'b1;
   endcase
   case({source_event,committing})
    2'b10:if(due!=7)due<=due+1'b1;
    2'b01:due<=due-1'b1;
   endcase
   case(state)
    IDLE:begin
     if(request_line || (!ready && first_frame_buffered))begin
      target_row<=ready?row_sync:9'd0;token<=req_sync;gap<=0;state<=LSTART;
     end else if(sample_valid && sample_ready)begin
      words[input_word*32+:32]<=sample_data;
      if(input_word==3)begin
       input_word<=0;write_offset<=written;wi<=0;state<=WRITE;
      end else input_word<=input_word+1'b1;
     end
    end
    WRITE:begin
     written<=written+1'b1;
     if(wi==3)begin
      if(written==64799)begin written<=0;write_bank<=write_bank+1'b1;end
      gap<=0;state<=GAP;
     end else wi<=wi+1'b1;
    end
    GAP:if(gap==31)state<=IDLE;else gap<=gap+1'b1;
    LSTART:if(gap!=31)begin
     gap<=gap+1'b1;
     if(gap==0)begin
      black_line<=target_row>=480;
      if(!ready || (target_row==0 && !paused && due!=0 && pending))begin
       display_bank<=display_bank+1'b1;
       line_base<=bank_base(display_bank+2'd1);
       displayed_frames<=displayed_frames+1'b1;
      end else begin
       line_base<=bank_base(display_bank)+
          {4'd0,native_row,8'd0}-{8'd0,native_row,4'd0};
       if(target_row==0 && !paused)begin
        if(due!=0 && !pending)late_frames<=late_frames+1'b1;
       end
      end
     end
    end
     else if(!refresh_busy)begin issued<=0;received<=0;state<=LINE;end
    LINE:begin
     if(rd_en)issued<=issued+1'b1;
     if(black_line || rvalid)begin
      received<=received+1'b1;
      if(received==239)begin
       if(target_row[0])begin tag_odd<=target_row;valid_odd<=1;end
       else begin tag_even<=target_row;valid_even<=1;end
       line_ack_toggle<=token;ready<=1;state<=IDLE;
      end
     end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
