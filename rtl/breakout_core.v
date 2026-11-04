// Game state lives entirely in registers. One shared AABB tests 32 bricks
// sequentially during vertical blank; no framebuffer, divider, multiplier or RAM.
module breakout_core #(parameter RUNNER=0)(input wire clk,rst,vs,active,
 input wire left_held,right_held,left_click,right_click,confirm,
 output reg view_game,selected,output reg [2:0] state,
 output reg [1:0] level,lives,output reg [15:0] score,output reg [31:0] bricks,
 output reg [9:0] paddle_x,output wire [9:0] ball_x,output wire [8:0] ball_y,
 output reg [9:0] trail_x0,trail_x1,trail_x2,output reg [8:0] trail_y0,trail_y1,trail_y2,
 output reg [9:0] hit_x,output reg [8:0] hit_y,output reg [3:0] hit_timer);
 localparam READY=0,PLAY=1,PAUSE=2,CLEAR=3,OVER=4,WIN=5;
 localparam IDLE=0,SCAN=1,COMMIT=2,PREP=3;
 reg vs_q,pending_left,pending_right,pending_confirm;
 wire frame_tick=vs_q && !vs;
 wire take_confirm=pending_confirm || confirm;
 reg [1:0] phase;reg [4:0] scan_index;reg [5:0] remaining;
 reg signed [12:0] ball_fx,ball_fy,work_x,work_y;
 reg signed [4:0] vel_x,vel_y,work_vx,work_vy;
 assign ball_x=ball_fx[11:2];assign ball_y=ball_fy[10:2];
 reg [9:0] next_paddle;
 reg signed [12:0] next_x,next_y;
 reg signed [4:0] next_vx,next_vy;
 reg miss;
 reg signed [12:0] raw_x,raw_y;reg [9:0] raw_paddle;
 wire signed [4:0] speed_y=level==1?5'sd10:level==2?5'sd12:5'sd14;
 wire [9:0] brick_left=10'd64+{1'b0,scan_index[2:0],6'd0};
 wire [8:0] brick_top=9'd128+{2'd0,scan_index[4:3],5'd0}-{5'd0,scan_index[4:3],2'd0};
 wire [9:0] cx=work_x[11:2];wire [8:0] cy=work_y[10:2];
 wire overlap=bricks[scan_index] && cx+10'd4>brick_left && cx<brick_left+10'd60 &&
     cy+9'd4>brick_top && cy<brick_top+9'd24;
 always @*begin
  next_paddle=paddle_x;
  if(left_held && !right_held)next_paddle=paddle_x<42?10'd36:paddle_x-10'd6;
  if(right_held && !left_held)next_paddle=paddle_x>510?10'd516:paddle_x+10'd6;
  next_x=raw_x;next_y=raw_y;
  next_vx=vel_x;next_vy=vel_y;miss=0;
  if(next_x<13'sd136)begin next_x=13'sd136;next_vx=-vel_x;end
  else if(next_x>13'sd2424)begin next_x=13'sd2424;next_vx=-vel_x;end
  if(next_y<13'sd488)begin next_y=13'sd488;next_vy=-vel_y;end
  // Paddle crossing uses the previous and proposed vertical coordinates.
  if(vel_y>0 && ball_fy<=13'sd1640 && next_y>=13'sd1640 &&
     next_x+13'sd16>$signed({1'b0,raw_paddle,2'd0}) &&
     next_x<$signed({1'b0,raw_paddle,2'd0})+13'sd368)begin
   next_y=13'sd1640;next_vy=-speed_y;
   if(next_x<$signed({1'b0,raw_paddle,2'd0})+13'sd64)next_vx=-5'sd12;
   else if(next_x<$signed({1'b0,raw_paddle,2'd0})+13'sd128)next_vx=-5'sd8;
   else if(next_x<$signed({1'b0,raw_paddle,2'd0})+13'sd224)next_vx=vel_x<0?-5'sd4:5'sd4;
   else if(next_x<$signed({1'b0,raw_paddle,2'd0})+13'sd288)next_vx=5'sd8;
   else next_vx=5'sd12;
  end
  if(next_y>13'sd1792)miss=1;
 end
 task reset_trails;input [9:0] px;input [8:0] py;begin
  trail_x0<=px;trail_x1<=px;trail_x2<=px;trail_y0<=py;trail_y1<=py;trail_y2<=py;
 end endtask
 task new_board;begin
  bricks<=32'hffffffff;remaining<=32;paddle_x<=276;ball_fx<=1280;ball_fy<=1624;
  vel_x<=8;vel_y<=-speed_y;state<=READY;phase<=IDLE;hit_timer<=0;reset_trails(320,406);
 end endtask
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   raw_x<=0;raw_y<=0;raw_paddle<=276;
   vs_q<=1;pending_left<=0;pending_right<=0;pending_confirm<=0;view_game<=0;selected<=0;
   level<=1;lives<=3;score<=0;state<=READY;phase<=IDLE;scan_index<=0;remaining<=32;
   bricks<=32'hffffffff;paddle_x<=276;ball_fx<=1280;ball_fy<=1624;vel_x<=8;vel_y<=-10;
   work_x<=1280;work_y<=1624;work_vx<=8;work_vy<=-10;hit_x<=0;hit_y<=0;hit_timer<=0;
   reset_trails(320,406);
  end else begin
   vs_q<=vs;
   if(!active)begin
    view_game<=0;state<=READY;phase<=IDLE;pending_left<=0;pending_right<=0;pending_confirm<=0;
   end else begin
    if(left_click)pending_left<=1;if(right_click)pending_right<=1;if(confirm)pending_confirm<=1;
    if(frame_tick && phase==IDLE)begin
     pending_left<=0;pending_right<=0;pending_confirm<=0;
     if(hit_timer!=0 && state==PLAY)hit_timer<=hit_timer-1'b1;
     if(!view_game)begin
      if(pending_left || pending_right || left_click || right_click)selected<=~selected;
      else if(take_confirm && (!selected || RUNNER))begin view_game<=1;level<=1;lives<=3;score<=0;new_board();end
     end else if(!selected && take_confirm)begin
      case(state)
       READY:begin state<=PLAY;vel_x<=left_held && !right_held?-5'sd8:5'sd8;vel_y<=-speed_y;end
       PLAY:state<=PAUSE;
       PAUSE:state<=PLAY;
       CLEAR:begin level<=level+1'b1;new_board();end
       OVER,WIN:begin level<=1;lives<=3;score<=0;new_board();end
       default:state<=READY;
      endcase
     end else if(!selected && state==READY)begin
      paddle_x<=next_paddle;ball_fx<={1'b0,next_paddle,2'd0}+13'd176;ball_fy<=1624;
      reset_trails(next_paddle+10'd44,9'd406);
     end else if(!selected && state==PLAY)begin
      // Split fixed-point addition from wall/paddle steering. Both phases
      // finish well within the same vertical blank, without changing physics.
      paddle_x<=next_paddle;raw_paddle<=next_paddle;
      raw_x<=ball_fx+{{8{vel_x[4]}},vel_x};raw_y<=ball_fy+{{8{vel_y[4]}},vel_y};phase<=PREP;
     end
    end
    if(phase==PREP && !selected)begin
      if(miss)begin
       lives<=lives-1'b1;state<=lives==1?OVER:READY;phase<=IDLE;
       ball_fx<={1'b0,raw_paddle,2'd0}+13'd176;ball_fy<=1624;vel_x<=8;vel_y<=-speed_y;
       reset_trails(raw_paddle+10'd44,9'd406);
      end else begin
       work_x<=next_x;work_y<=next_y;work_vx<=next_vx;work_vy<=next_vy;
       // Ball/paddle crossing already computed in PREP: reflect visibly once.
       if(vel_y>0 && next_vy<0)begin
        hit_x<=next_x[11:2]+10'd2;hit_y<=9'd412;hit_timer<=8;
       end
       scan_index<=0;phase<=SCAN;
       trail_x2<=trail_x1;trail_y2<=trail_y1;trail_x1<=trail_x0;trail_y1<=trail_y0;
       trail_x0<=ball_x;trail_y0<=ball_y;
      end
    end else if(phase==SCAN && !selected)begin
     if(overlap)begin
      bricks[scan_index]<=0;remaining<=remaining-1'b1;
      hit_x<=brick_left+10'd28;hit_y<=brick_top+9'd10;hit_timer<=12;
      // Integer BCD score increments by ten without a binary-to-decimal divider.
      if(score[7:4]==9)begin score[7:4]<=0;
       if(score[11:8]==9)begin score[11:8]<=0;score[15:12]<=score[15:12]+1'b1;end
       else score[11:8]<=score[11:8]+1'b1;
      end else score[7:4]<=score[7:4]+1'b1;
      if(ball_y+9'd4<=brick_top || ball_y>=brick_top+9'd24)begin
       work_vy<=-work_vy;
       work_y<=work_vy>0?{2'd0,brick_top,2'd0}-13'd16:({2'd0,brick_top,2'd0}+13'd96);
      end else begin
       work_vx<=-work_vx;
       work_x<=work_vx>0?{1'b0,brick_left,2'd0}-13'd16:({1'b0,brick_left,2'd0}+13'd240);
      end
      if(remaining==1)state<=level==3?WIN:CLEAR;
      phase<=COMMIT;
     end else if(scan_index==31)phase<=COMMIT;
     else scan_index<=scan_index+1'b1;
    end else if(phase==COMMIT && !selected)begin
     ball_fx<=work_x;ball_fy<=work_y;vel_x<=work_vx;vel_y<=work_vy;phase<=IDLE;
    end
   end
  end
 end
endmodule
