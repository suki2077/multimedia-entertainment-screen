// Streaming aspect-preserving FIT. Two horizontally resized RGB888 rows,
// bilinear Q12 coordinates / Q8 weights, no source-frame allocation.
// Input pixels are in BMP storage order. Output is exactly 640*480 / 4 groups,
// including centered black bars; each destination address is written once.
module bmp_fit_scaler(input wire clk,rst,start,input wire[12:0] width,height,
 input wire top_down,input wire raw_valid,input wire[23:0] raw_rgb,
 output wire raw_ready,output reg group_valid,input wire group_ready,
 output reg[20:0] group_addr,output reg[127:0] group_data,
 output reg done,failed);
 localparam IDLE=0,FIT_START=1,FIT_WAIT=2,X_START=3,X_WAIT=4,Y_START=5,Y_WAIT=6,
  ROW=7,CHECK=8,SKIP=9,PREFIX=10,H_READ=11,H_EVAL=12,H_LERP=13,H_WRITE=14,
  SUFFIX=15,TAIL=16,DRAIN=17,PUBLISH=18,V_ADDR=19,V_WAIT=20,V_CAPTURE=21,
  V_WAIT_B=22,V_START=23,V_LERP=24,PACK=25,SEND=26,BLACK=27,FINISH=28,ERROR=29,CHECK_PRE=30;
 reg[5:0] state;reg cached_all_q;reg [11:0] need_y_q;reg[12:0] sw,sh;reg td,wide;
 reg[9:0] dw,dh,padx,pady;reg[23:0] xstep,ystep,xcoord,ycoord;
 reg[9:0] xrem,yrem,xphase,yphase;
 wire[10:0] xphase_sum={1'b0,xphase}+{1'b0,xrem};
 wire[10:0] yphase_sum={1'b0,yphase}+{1'b0,yrem};
 reg div_start;reg[23:0] div_n;reg[12:0] div_d;
 wire[23:0] quotient;wire[12:0] remainder;wire div_busy,div_done;
 scale_divider u_div(clk,rst,div_start,div_n,div_d,quotient,remainder,div_busy,div_done);
 reg lerp_start;reg[23:0] lerp_a,lerp_b;reg[7:0] lerp_fraction;
 wire[23:0] lerp_result;wire lerp_done;
 scale_lerp u_lerp(clk,rst,lerp_start,lerp_a,lerp_b,lerp_fraction,lerp_result,lerp_done);
 reg line_we;reg[10:0] line_wa,line_ra;reg[23:0] line_data;wire[23:0] line_q;
 album_line_buffer u_rows(clk,line_we,line_wa,line_data,clk,line_ra,line_q);
 reg[11:0] tag0,tag1;reg valid0,valid1;
 reg[12:0] sy;reg[11:0] sx,fill_y,curr_x;reg row_read_done;
 reg[23:0] previous,current,hpixel,opixel;
 reg[9:0] hx,dx,ox;reg[8:0] oy;reg[20:0] row_base;
 reg[1:0] slot;reg active_row;
 wire[11:0] y0=ycoord[23:12];
 wire[11:0] y1=({1'b0,y0}+13'd1<sh)?y0+1'b1:y0;
 wire yblend=(ycoord[11:4]!=0)&&(y0!=y1);
 wire cached0=y0[0]?(valid1&&tag1==y0):(valid0&&tag0==y0);
 wire cached1=y1[0]?(valid1&&tag1==y1):(valid0&&tag0==y1);
 wire[11:0] need_y=!cached0?y0:y1;
 wire[11:0] x0=xcoord[23:12];
 wire xblend=(xcoord[11:4]!=0)&&({1'b0,x0}+13'd1<sw);
 wire[11:0] need_x=xblend?x0+1'b1:x0;
 // Geometry is fixed before the X/Y divider setup completes. Register bounds
 // so subtraction and row comparisons do not share a single timing path.
 reg[9:0] raw_pad_y,raw_end_y;
 always @(posedge clk or posedge rst)begin
  if(rst)begin raw_pad_y<=0;raw_end_y<=0;end
  else begin raw_pad_y<=td?pady:10'd480-dh-pady;raw_end_y<=raw_pad_y+dh;end
 end
 assign raw_ready=(state==H_READ||state==SKIP||state==DRAIN||state==FINISH);
 task advance_source;
  begin if({1'b0,sx}+13'd1==sw)begin sx<=0;sy<=sy+1'b1;end else sx<=sx+1'b1;end
 endtask
 task advance_x;
  begin
   if(xphase_sum>=dw-1'b1)begin xphase<=xphase_sum-(dw-1'b1);xcoord<=xcoord+xstep+1'b1;end
   else begin xphase<=xphase_sum;xcoord<=xcoord+xstep;end
  end
 endtask
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;cached_all_q<=0;need_y_q<=0;sw<=0;sh<=0;td<=0;wide<=0;dw<=0;dh<=0;padx<=0;pady<=0;
   xstep<=0;ystep<=0;xcoord<=0;ycoord<=0;xrem<=0;yrem<=0;xphase<=0;yphase<=0;
   div_start<=0;div_n<=0;div_d<=1;lerp_start<=0;lerp_a<=0;lerp_b<=0;lerp_fraction<=0;
   line_we<=0;line_wa<=0;line_ra<=0;line_data<=0;tag0<=0;tag1<=0;valid0<=0;valid1<=0;
   sy<=0;sx<=0;fill_y<=0;curr_x<=0;row_read_done<=0;previous<=0;current<=0;hpixel<=0;opixel<=0;
   hx<=0;dx<=0;ox<=0;oy<=0;row_base<=0;slot<=0;active_row<=0;
   group_valid<=0;group_addr<=0;group_data<=0;done<=0;failed<=0;
  end else begin
   div_start<=0;lerp_start<=0;line_we<=0;
   case(state)
    IDLE:if(start)begin
     sw<=width;sh<=height;td<=top_down;wide<=({width,1'b0}+width)>={height,2'b0};
     // 3*width is a 15-bit comparison, including 4096-wide images.
     state<=FIT_START;
    end
    FIT_START:begin
     div_n<=wide?(sh*24'd640):(sw*24'd480);div_d<=wide?sw:sh;div_start<=1;state<=FIT_WAIT;
    end
    FIT_WAIT:if(div_done)begin
     dw<=wide?10'd640:(quotient==0?10'd1:quotient[9:0]);
     dh<=wide?(quotient==0?10'd1:quotient[9:0]):10'd480;state<=X_START;
    end
    X_START:begin
     padx<=(640-dw)>>1;pady<=(480-dh)>>1;
     div_n<=(sw-13'd1)<<12;div_d<=dw>1?dw-1'b1:13'd1;div_start<=1;state<=X_WAIT;
    end
    X_WAIT:if(div_done)begin
     xstep<=dw>1?quotient:24'd0;xrem<=dw>1?remainder[9:0]:10'd0;state<=Y_START;
    end
    Y_START:begin div_n<=(sh-13'd1)<<12;div_d<=dh>1?dh-1'b1:13'd1;div_start<=1;state<=Y_WAIT;end
    Y_WAIT:if(div_done)begin
     ystep<=dh>1?quotient:24'd0;yrem<=dh>1?remainder[9:0]:10'd0;
     ycoord<=dh>1?24'd0:((sh-13'd1)<<11);yphase<=0;
     row_base<=td?21'd0:21'd306560;state<=ROW;
    end
    ROW:begin
     if(oy>=raw_pad_y&&oy<raw_end_y)begin active_row<=1;state<=CHECK_PRE;end
     else begin active_row<=0;state<=BLACK;end
    end
    CHECK_PRE:begin cached_all_q<=cached0&&(!yblend||cached1);need_y_q<=need_y;state<=CHECK;end
    CHECK:begin
     if(cached_all_q)state<=V_ADDR;
     else if(sy>{1'b0,need_y_q})begin failed<=1;state<=ERROR;end
     else if(sy<{1'b0,need_y_q})state<=SKIP;
     else begin
      fill_y<=need_y_q;hx<=0;dx<=0;xcoord<=dw>1?24'd0:((sw-13'd1)<<11);xphase<=0;
      row_read_done<=0;state<=PREFIX;
     end
    end
    SKIP:if(raw_valid)begin advance_source();if({1'b0,sx}+13'd1==sw)state<=CHECK_PRE;end
    PREFIX:if(hx<padx)begin line_we<=1;line_wa<={fill_y[0],hx};line_data<=0;hx<=hx+1'b1;end
     else state<=H_READ;
    H_READ:if(raw_valid)begin
     previous<=current;current<=raw_rgb;curr_x<=sx;advance_source();
     if({1'b0,sx}+13'd1==sw)row_read_done<=1;state<=H_EVAL;
    end
    H_EVAL:if(curr_x<need_x)state<=H_READ;
     else if(!xblend)begin hpixel<=current;state<=H_WRITE;end
     else begin lerp_a<=previous;lerp_b<=current;lerp_fraction<=xcoord[11:4];lerp_start<=1;state<=H_LERP;end
    H_LERP:if(lerp_done)begin hpixel<=lerp_result;state<=H_WRITE;end
    H_WRITE:begin
     line_we<=1;line_wa<={fill_y[0],hx};line_data<=hpixel;hx<=hx+1'b1;
     if(dx==dw-1'b1)state<=SUFFIX;
     else begin dx<=dx+1'b1;advance_x();state<=H_EVAL;end
    end
    SUFFIX:if(hx<640)begin line_we<=1;line_wa<={fill_y[0],hx};line_data<=0;hx<=hx+1'b1;end
     else state<=TAIL;
    TAIL:state<=row_read_done?PUBLISH:DRAIN;
    DRAIN:if(raw_valid)begin advance_source();if({1'b0,sx}+13'd1==sw)state<=PUBLISH;end
    PUBLISH:begin
     if(fill_y[0])begin valid1<=1;tag1<=fill_y;end else begin valid0<=1;tag0<=fill_y;end
     state<=CHECK_PRE;
    end
    V_ADDR:begin line_ra<={y0[0],ox};state<=V_WAIT;end
    V_WAIT:state<=V_CAPTURE;
    V_CAPTURE:if(!yblend)begin opixel<=line_q;state<=PACK;end
     else begin lerp_a<=line_q;line_ra<={y1[0],ox};state<=V_WAIT_B;end
    V_WAIT_B:state<=V_START;
    V_START:begin lerp_b<=line_q;lerp_fraction<=ycoord[11:4];lerp_start<=1;state<=V_LERP;end
    V_LERP:if(lerp_done)begin opixel<=lerp_result;state<=PACK;end
    BLACK:begin opixel<=0;state<=PACK;end
    PACK:begin
     group_data[slot*32+:32]<={8'd0,opixel};
     if(slot==3)begin slot<=0;group_addr<=row_base+ox-3;group_valid<=1;state<=SEND;end
     else begin slot<=slot+1'b1;ox<=ox+1'b1;state<=active_row?V_ADDR:BLACK;end
    end
    SEND:if(group_ready)begin
     group_valid<=0;
     if(ox==639)begin
      ox<=0;oy<=oy+1'b1;row_base<=td?row_base+640:row_base-640;
      if(active_row&&dh>1)begin
       if(yphase_sum>=dh-1'b1)begin yphase<=yphase_sum-(dh-1'b1);ycoord<=ycoord+ystep+1'b1;end
       else begin yphase<=yphase_sum;ycoord<=ycoord+ystep;end
      end
      if(oy==479)begin done<=1;state<=FINISH;end else state<=ROW;
     end else begin ox<=ox+1'b1;state<=active_row?V_ADDR:BLACK;end
    end
    FINISH:state<=FINISH;
    ERROR:state<=ERROR;
    default:begin failed<=1;state<=ERROR;end
   endcase
  end
 end
endmodule
