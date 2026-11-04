// Four tagged 640x480 RGB cache slots (up to twenty logical images) in the 2M x 32-bit SDRAM (1,228,800 words).
// Group writes and priority line reads retain the proven SDRAM transaction gaps.
// New jobs are applied only after any current burst/line has drained.
module frame_store_cached #(parameter WATCHDOG_LIMIT=71428571,MAX_IMAGES=4,IMAGE_BITS=$clog2(MAX_IMAGES))(
 input wire clk,rst,init_done,refresh_busy,
 input wire group_valid,output wire group_ready,input wire [20:0] group_addr,input wire [127:0] group_data,
 input wire load_done,load_failed,begin_load,swap_allowed,prefetch,promote,
 output wire frame_pending,input wire [IMAGE_BITS-1:0] image_index,
 output reg [MAX_IMAGES-1:0] cache_valid,output reg swapped,output reg [IMAGE_BITS-1:0] displayed,
 output wire wr_en,output wire [20:0] wr_addr,output wire [31:0] wr_data,
 output wire rd_en,output wire [20:0] rd_addr,input wire rd_valid,input wire [31:0] rd_data,
 input wire line_req_toggle,input wire [8:0] line_req_row,output reg line_ack_toggle,
 output wire line_we,output wire [10:0] line_waddr,output wire [23:0] line_wdata,
 output reg [8:0] tag_even,tag_odd,output reg valid_even,valid_odd,
 output reg committed,ready,failed,input wire [4:0] photo_count,output wire [4*IMAGE_BITS-1:0] cache_tags,output wire [3:0] cache_slots_valid);
 localparam LOAD=0,WRITE=1,GAP=2,LSTART=3,LINE=4,SELECT_SLOT=5,FAIL=6,APPLY_JOB=7;
 reg [2:0] state;
 reg [20:0] write_base,display_base,back_base,line_base;
 reg pending,loading,background,job_pending,request_background;
 reg [IMAGE_BITS-1:0] loading_index,request_index;
 reg [IMAGE_BITS-1:0] tag0,tag1,tag2,tag3;
 reg [3:0] slot_valid;reg [1:0] loading_slot,display_slot,victim;
 assign cache_tags={tag3,tag2,tag1,tag0};assign cache_slots_valid=slot_valid;
 reg request_hit;reg [1:0] request_slot;
 always @*begin
  cache_valid=0;
  if(slot_valid[0])cache_valid[tag0]=1;
  if(slot_valid[1])cache_valid[tag1]=1;
  if(slot_valid[2])cache_valid[tag2]=1;
  if(slot_valid[3])cache_valid[tag3]=1;
  request_hit=0;request_slot=0;
  if(slot_valid[0] && tag0==request_index)begin request_hit=1;request_slot=0;end
  else if(slot_valid[1] && tag1==request_index)begin request_hit=1;request_slot=1;end
  else if(slot_valid[2] && tag2==request_index)begin request_hit=1;request_slot=2;end
  else if(slot_valid[3] && tag3==request_index)begin request_hit=1;request_slot=3;end
 end
 wire [4:0] total_images=MAX_IMAGES==4?5'd4:photo_count;
 // Neighbour arithmetic is independent of cache tag comparisons. Register it
 // before choosing a slot; SELECT/APPLY also separates replacement from tag writes.
 reg [IMAGE_BITS-1:0] keep_next,keep_prev;
 reg [1:0] chosen_slot_q;
 reg request_hit_q;
 always @(posedge clk or posedge rst) begin
  if(rst)begin keep_next<=0;keep_prev<=0;end
  else begin
   keep_next<=displayed+1'b1>=total_images?0:displayed+1'b1;
   keep_prev<=displayed==0?total_images-1'b1:displayed-1'b1;
  end
 end
 reg [1:0] replacement;
 always @*begin
  replacement=(ready && victim==display_slot)?victim+2'd1:victim;
  if(!ready)replacement=0;
  else if(!slot_valid[0] && display_slot!=0)replacement=0;
  else if(!slot_valid[1] && display_slot!=1)replacement=1;
  else if(!slot_valid[2] && display_slot!=2)replacement=2;
  else if(!slot_valid[3] && display_slot!=3)replacement=3;
  else if(display_slot!=0 && tag0!=keep_next && tag0!=keep_prev)replacement=0;
  else if(display_slot!=1 && tag1!=keep_next && tag1!=keep_prev)replacement=1;
  else if(display_slot!=2 && tag2!=keep_next && tag2!=keep_prev)replacement=2;
  else if(display_slot!=3 && tag3!=keep_next && tag3!=keep_prev)replacement=3;
 end
 wire [1:0] chosen_slot=request_hit?request_slot:replacement;
 reg allow_meta,allow_sync;
 reg [127:0] write_words;reg [1:0] word_index;
 reg [18:0] written;reg [5:0] gap;reg [9:0] issued,received;reg [8:0] target_row;
 reg pending_token,req_meta,req_sync;reg [26:0] watchdog;reg rvalid;reg [31:0] rdata;
 function [20:0] slot_base;input [1:0] index;begin case(index)
  0:slot_base=0;1:slot_base=307200;2:slot_base=614400;3:slot_base=921600;
 endcase end endfunction
 assign frame_pending=pending && ready && !job_pending && !begin_load;
 assign group_ready=state==LOAD && init_done && !refresh_busy && !load_failed && loading &&
     !pending && !job_pending && !begin_load && written<307200 && (req_sync==line_ack_toggle || !ready);
 assign wr_en=state==WRITE;assign wr_addr=write_base+word_index;assign wr_data=write_words[word_index*32+:32];
 assign rd_en=state==LINE && issued<640;assign rd_addr=line_base+issued;
 assign line_we=state==LINE && rvalid;assign line_waddr={target_row[0],received};assign line_wdata=rdata[23:0];
 always @(posedge clk or posedge rst)begin
  if(rst)begin allow_meta<=0;allow_sync<=0;req_meta<=0;req_sync<=0;rvalid<=0;rdata<=0;end
  else begin allow_meta<=swap_allowed;allow_sync<=allow_meta;req_meta<=line_req_toggle;req_sync<=req_meta;rvalid<=rd_valid;rdata<=rd_data;end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=LOAD;chosen_slot_q<=0;request_hit_q<=0;display_base<=0;back_base<=0;line_base<=0;pending<=0;loading<=0;background<=0;
   job_pending<=0;request_background<=0;loading_index<=0;request_index<=0;slot_valid<=0;tag0<=0;tag1<=0;tag2<=0;tag3<=0;loading_slot<=0;display_slot<=0;victim<=0;
   swapped<=0;displayed<=0;write_base<=0;write_words<=0;word_index<=0;written<=0;
   gap<=0;issued<=0;received<=0;target_row<=0;pending_token<=0;
   line_ack_toggle<=0;tag_even<=0;tag_odd<=0;valid_even<=0;valid_odd<=0;
   committed<=0;ready<=0;failed<=0;watchdog<=0;
  end else begin
   swapped<=0;
   if(begin_load)begin
    job_pending<=1;request_index<=image_index;request_background<=prefetch;
    pending<=0;loading<=0;
   end
   if(promote)begin
    background<=0;request_background<=0;
    if(slot_valid[loading_slot] && !job_pending)pending<=1;
   end
   if(load_failed && !begin_load && !job_pending)begin loading<=0;pending<=0;end
   if(state==LOAD || state==FAIL || rd_en || wr_en || rvalid)watchdog<=0;
   else watchdog<=watchdog+1'b1;
   case(state)
    LOAD:begin
     if(begin_load)begin end
     else if(job_pending)begin
      state<=SELECT_SLOT;
     end else if(ready && req_sync!=line_ack_toggle)begin
      target_row<=line_req_row;pending_token<=req_sync;gap<=0;line_base<=display_base;state<=LSTART;
     end else if(!ready && pending)begin
      display_base<=back_base;line_base<=back_base;target_row<=0;pending_token<=req_sync;
      gap<=0;pending<=0;loading<=0;displayed<=loading_index;display_slot<=loading_slot;swapped<=1;committed<=1;state<=LSTART;
     end else if(written==307200 && load_done && loading && !load_failed)begin
      slot_valid[loading_slot]<=1;loading<=0;
      if(!background || promote)pending<=1;
     end else if(group_valid && group_ready)begin
      if(group_addr[1:0]!=0 || group_addr>307196 || (ready && loading_slot==display_slot))begin failed<=1;state<=FAIL;end
      else begin write_base<=back_base+group_addr;write_words<=group_data;word_index<=0;state<=WRITE;end
     end
    end
    SELECT_SLOT:begin
     if(begin_load)state<=LOAD;
     else begin chosen_slot_q<=chosen_slot;request_hit_q<=request_hit;state<=APPLY_JOB;end
    end
    APPLY_JOB:begin
     if(begin_load)state<=LOAD;
     else begin
      job_pending<=0;written<=0;loading_index<=request_index;background<=request_background && !promote;
      back_base<=slot_base(chosen_slot_q);loading_slot<=chosen_slot_q;
      if(!request_hit_q)begin
       slot_valid[chosen_slot_q]<=0;victim<=chosen_slot_q+2'd1;
       case(chosen_slot_q)0:tag0<=request_index;1:tag1<=request_index;2:tag2<=request_index;3:tag3<=request_index;endcase
      end
      loading<=!request_hit_q;pending<=request_hit_q && (!request_background || promote);state<=LOAD;
     end
    end
    WRITE:begin
     written<=written+1'b1;
     if(word_index==3)begin gap<=0;state<=GAP;end else word_index<=word_index+1'b1;
    end
    GAP:if(gap==31)state<=LOAD;else gap<=gap+1'b1;
    LSTART:if(gap<31)begin
     gap<=gap+1'b1;
     if(gap==0)begin
      if(pending && target_row==0 && allow_sync && !job_pending && !begin_load)begin
       display_base<=back_base;line_base<=back_base;displayed<=loading_index;display_slot<=loading_slot;
       pending<=0;loading<=0;swapped<=1;
      end else line_base<=line_base+target_row*21'd640;
     end
    end else if(!refresh_busy)begin issued<=0;received<=0;state<=LINE;end
    LINE:begin
     if(rd_en)issued<=issued+1'b1;
     if(rvalid)begin
      received<=received+1'b1;
      if(received==639)begin
       if(target_row[0])begin tag_odd<=target_row;valid_odd<=1;end else begin tag_even<=target_row;valid_even<=1;end
       line_ack_toggle<=pending_token;ready<=1;state<=LOAD;
      end
     end
    end
    FAIL:state<=FAIL;
    default:begin state<=FAIL;failed<=1;end
   endcase
   if(state!=FAIL && watchdog>=WATCHDOG_LIMIT)begin failed<=1;ready<=0;state<=FAIL;end
  end
 end
endmodule
