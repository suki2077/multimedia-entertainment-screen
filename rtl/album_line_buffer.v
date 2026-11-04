// Lossless 3 x RGB888 packing: two 640-pixel rows occupy 428 x 72 bits.
// One 72-bit write per three incoming pixels; 640th pixel flushes padded tail.
// Synchronous group read plus registered slot retains one-pixel read latency.
module album_line_buffer(input wire wclk,we,input wire [10:0] waddr,input wire [23:0] wdata,
 input wire rclk,input wire [10:0] raddr,output wire [23:0] q);
 reg [71:0] data[0:511];reg [47:0] assemble;
 wire [9:0] wx=waddr[9:0],rx=raddr[9:0];
 wire [8:0] wgroup=wx/10'd3,rgroup=rx/10'd3;
 wire [1:0] wslot=wx-wgroup*10'd3,rslot=rx-rgroup*10'd3;
 reg wen_q,tail_q,bank_q;reg [8:0] group_q;reg [1:0] write_slot_q;reg [23:0] write_pixel_q;
 always @(posedge wclk)begin
  wen_q<=we && wx<640;tail_q<=wx==639;bank_q<=waddr[10];group_q<=wgroup;
  write_slot_q<=wslot;write_pixel_q<=wdata;
 end
 wire [8:0] wa=(bank_q?9'd214:9'd0)+group_q;
 wire [8:0] ra=(raddr[10]?9'd214:9'd0)+rgroup;
 always @(posedge wclk)if(wen_q)begin
  if(tail_q)data[wa]<={48'd0,write_pixel_q};
  else case(write_slot_q)
   0:assemble[23:0]<=write_pixel_q;
   1:assemble[47:24]<=write_pixel_q;
   2:data[wa]<={write_pixel_q,assemble};
  endcase
 end
 reg[71:0] word_q;reg[1:0] slot_q;
 always @(posedge rclk)begin word_q<=data[ra];slot_q<=rslot;end
 assign q=slot_q==0?word_q[23:0]:slot_q==1?word_q[47:24]:word_q[71:48];
endmodule
