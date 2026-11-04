// One physical 512 x 72 dual-clock RAM, shared by RGB888 album groups and
// packed RGB565 video words. Owner changes only while both engines are reset.
module line_buffer #(parameter SMOOTH_VIDEO=0)(input wire wclk,we,input wire [10:0] waddr,input wire [31:0] wdata,
 input wire wvideo,input wire rclk,input wire [10:0] raddr,input wire rvideo,output wire [23:0] q,input wire [2:0] rfrac);
 reg [71:0] data[0:511];reg [47:0] assemble;
 wire [9:0] wx=waddr[9:0],rx=raddr[9:0];
 wire [8:0] wgroup=wvideo?{1'b0,wx[7:0]}:wx/10'd3;
 wire [8:0] rgroup=rvideo?{1'b0,rx[8:1]}:rx/10'd3;
 wire [1:0] wslot=wx-wgroup*10'd3,rslot=rvideo?{1'b0,rx[0]}:rx-rgroup*10'd3;
 wire [8:0] wa={waddr[10],wgroup[7:0]};
 wire [8:0] ra={raddr[10],rgroup[7:0]};
 // Register the full write transaction before the wide RAM port.
 reg we_q,video_wq,tail_q,valid_wq;reg [8:0] wa_q;reg [1:0] wslot_q;
 reg [31:0] wdata_q;
 reg [31:0] video_previous;reg [8:0] video_previous_addr;
 reg video_tail;reg first_q,last_q;
 // Existing 72-bit words have room for three RGB565 neighbours. No extra RAM/SD reads.
 // Delay one pair on write to attach the first pixel of the following pair.

 always @(posedge wclk)begin
  we_q<=we;video_wq<=wvideo;tail_q<=wx==639;
  valid_wq<=wvideo?(wx<240):(wx<640);
  wa_q<=wa;wslot_q<=wslot;wdata_q<=wdata;
  first_q<=wx==0;last_q<=wx==239;
  video_tail<=SMOOTH_VIDEO && we_q && valid_wq && video_wq && last_q;
  if(SMOOTH_VIDEO && we_q && valid_wq && video_wq)begin
   video_previous<=wdata_q;video_previous_addr<=wa_q;
  end

  if(SMOOTH_VIDEO && video_tail)data[video_previous_addr]<={24'd0,video_previous[31:16],video_previous};
  else if(we_q && valid_wq)begin
   if(video_wq)begin
    if(SMOOTH_VIDEO)begin
     if(!first_q)data[video_previous_addr]<={24'd0,wdata_q[15:0],video_previous};
    end else data[wa_q]<={40'd0,wdata_q};
   end
   else if(tail_q)data[wa_q]<={48'd0,wdata_q[23:0]};
   else case(wslot_q)
    0:assemble[23:0]<=wdata_q[23:0];
    1:assemble[47:24]<=wdata_q[23:0];
    2:data[wa_q]<={wdata_q[23:0],assemble};
   endcase
  end
 end
 reg [71:0] word_q;reg [1:0] slot_q;reg video_q;reg [2:0] frac_q;
 always @(posedge rclk)begin word_q<=data[ra];slot_q<=rslot;video_q<=rvideo;frac_q<=rfrac;end
 wire [15:0] c=slot_q[0]?word_q[31:16]:word_q[15:0];
 wire [23:0] expanded={c[15:11],c[15:13],c[10:5],c[10:9],c[4:0],c[4:2]};
 wire [15:0] neighbour=slot_q[0]?word_q[47:32]:word_q[31:16];
 wire [23:0] next_rgb={neighbour[15:11],neighbour[15:13],neighbour[10:5],neighbour[10:9],neighbour[4:0],neighbour[4:2]};
 function [7:0] lerp;input [7:0] a,b;input [2:0] f;
  reg signed [8:0] delta;reg signed [11:0] d,t;reg signed [12:0] value;
  begin
   delta=$signed({1'b0,b})-$signed({1'b0,a});d={{3{delta[8]}},delta};
   t=(f[0]?d:12'sd0)+(f[1]?(d<<<1):12'sd0)+(f[2]?(d<<<2):12'sd0);
   value=$signed({1'b0,a,3'b0})+t+13'sd4;lerp=value[10:3];
  end
 endfunction
 wire [23:0] smooth={lerp(expanded[23:16],next_rgb[23:16],frac_q),lerp(expanded[15:8],next_rgb[15:8],frac_q),lerp(expanded[7:0],next_rgb[7:0],frac_q)};
 assign q=video_q?(SMOOTH_VIDEO?smooth:expanded):slot_q==0?word_q[23:0]:slot_q==1?word_q[47:24]:word_q[71:48];
endmodule
