// Procedural arcade graphics, shared small font and a four-register pixel pipeline.
module arcade_renderer #(parameter RUNNER_DUCK=0,POLISH=0)(input wire clk,rst,input wire [9:0] x,y,
 input wire view_game,selected,input wire [2:0] state,input wire [1:0] level,lives,
 input wire [15:0] score,input wire [31:0] bricks,
 input wire [9:0] paddle_x,ball_x,trail_x0,trail_x1,trail_x2,
 input wire [8:0] ball_y,trail_y0,trail_y1,trail_y2,
 input wire [9:0] hit_x,input wire [8:0] hit_y,input wire [3:0] hit_timer,
 output reg [23:0] rgb,input wire runner_sliding,runner_overhead0,runner_overhead1);
  // One end-of-visible-frame pulse. All effects freeze with the game, and
  // reuse existing motion/impact data rather than storing particle objects.
  wire frame_mark=x==0 && y==479;
  reg frame_mark_q;reg [15:0] score_seen;reg [2:0] combo;
  reg [6:0] combo_hold;
  always @(posedge clk or posedge rst)begin
   if(rst)begin frame_mark_q<=0;score_seen<=0;combo<=0;combo_hold<=0;end
   else begin
    frame_mark_q<=frame_mark;
    if(!POLISH || !view_game || selected || state==0 || state==4)begin
     score_seen<=score;combo<=0;combo_hold<=0;
    end else if(frame_mark && !frame_mark_q && state==1)begin
     score_seen<=score;
     if(score!=score_seen)begin
      if(combo!=7)combo<=combo+1'b1;
      combo_hold<=90;
     end else if(combo_hold!=0)combo_hold<=combo_hold-1'b1;
     else combo<=0;
    end
   end
  end
  function [7:0] letter;input [5:0] id;input [5:0] pos;begin
 case(id)
 31:case(pos)
  0:letter=8'd48+score[15:12];
  1:letter=8'd48+score[11:8];
  2:letter=8'd48+score[7:4];
  3:letter=8'd48+score[3:0];
  default:letter=32;endcase
 33:case(pos)
  0:letter=8'd48+trail_x1[7:4];
  1:letter=8'd48+trail_x1[3:0];
  2:letter=8'd48+trail_x2[7:4];
  3:letter=8'd48+trail_x2[3:0];
  default:letter=32;endcase
 37:case(pos)
  0:letter=67;1:letter=79;2:letter=77;3:letter=66;4:letter=79;
  5:letter=32;6:letter=88;7:letter=48+{5'd0,combo};default:letter=32;endcase
 32:letter=pos==0?8'd48+{6'd0,level}:8'd32;
 default:letter=32;
 endcase end endfunction
 function [15:0] text_span;input [5:0] id;begin case(id)
 6'd0:text_span={10'd456,6'd12};
 6'd1:text_span={10'd13,6'd8};
 6'd2:text_span={10'd21,6'd11};
 6'd3:text_span={10'd32,6'd9};
 6'd4:text_span={10'd41,6'd6};
 6'd5:text_span={10'd47,6'd9};
 6'd6:text_span={10'd56,6'd14};
 6'd7:text_span={10'd70,6'd13};
 6'd8:text_span={10'd83,6'd10};
 6'd9:text_span={10'd93,6'd14};
 6'd10:text_span={10'd107,6'd5};
 6'd11:text_span={10'd112,6'd5};
 6'd12:text_span={10'd117,6'd5};
 6'd13:text_span={10'd122,6'd35};
 6'd14:text_span={10'd157,6'd13};
 6'd15:text_span={10'd170,6'd6};
 6'd16:text_span={10'd176,6'd11};
 6'd17:text_span={10'd187,6'd9};
 6'd18:text_span={10'd196,6'd7};
 6'd19:text_span={10'd203,6'd10};
 6'd20:text_span={10'd213,6'd11};
 6'd21:text_span={10'd224,6'd9};
 6'd22:text_span={10'd233,6'd10};
 6'd23:text_span={10'd243,6'd13};
 6'd24:text_span={10'd256,6'd21};
 6'd25:text_span={10'd277,6'd13};
 6'd26:text_span={10'd290,6'd25};
 6'd27:text_span={10'd315,6'd20};
 6'd28:text_span={10'd335,6'd24};
 6'd29:text_span={10'd359,6'd28};
 6'd30:text_span={10'd387,6'd6};
 6'd34:text_span={10'd393,6'd4};
 6'd35:text_span={10'd397,6'd33};
 6'd36:text_span={10'd430,6'd26};
 default:text_span=0;endcase end endfunction
 function [34:0] glyph;input [7:0] ch;begin case(ch)
 8'd65:glyph=35'b01110100011000111111100011000110001;
 8'd66:glyph=35'b11110100011000111110100011000111110;
 8'd67:glyph=35'b01111100001000010000100001000001111;
 8'd68:glyph=35'b11110100011000110001100011000111110;
 8'd69:glyph=35'b11111100001000011110100001000011111;
 8'd70:glyph=35'b11111100001000011110100001000010000;
 8'd71:glyph=35'b01111100001000010111100011000101111;
 8'd72:glyph=35'b10001100011000111111100011000110001;
 8'd73:glyph=35'b01110001000010000100001000010001110;
 8'd74:glyph=35'b00001000010000100001100011000101110;
 8'd75:glyph=35'b10001100101010011000101001001010001;
 8'd76:glyph=35'b10000100001000010000100001000011111;
 8'd77:glyph=35'b10001110111010110101100011000110001;
 8'd78:glyph=35'b10001110011100110101100111001110001;
 8'd79:glyph=35'b01110100011000110001100011000101110;
 8'd80:glyph=35'b11110100011000111110100001000010000;
 8'd81:glyph=35'b01110100011000110001101011001001101;
 8'd82:glyph=35'b11110100011000111110101001001010001;
 8'd83:glyph=35'b01111100001000001110000010000111110;
 8'd84:glyph=35'b11111001000010000100001000010000100;
 8'd85:glyph=35'b10001100011000110001100011000101110;
 8'd86:glyph=35'b10001100011000110001100010101000100;
 8'd87:glyph=35'b10001100011000110101101011010101010;
 8'd88:glyph=35'b10001100010101000100010101000110001;
 8'd89:glyph=35'b10001100010101000100001000010000100;
 8'd90:glyph=35'b11111000010001000100010001000011111;
 8'd48:glyph=35'b01110100011001110101110011000101110;
 8'd49:glyph=35'b00100011000010000100001000010001110;
 8'd50:glyph=35'b01110100010000100010001000100011111;
 8'd51:glyph=35'b11110000010000101110000010000111110;
 8'd52:glyph=35'b00010001100101010010111110001000010;
 8'd53:glyph=35'b11111100001000011110000010000111110;
 8'd54:glyph=35'b01110100001000011110100011000101110;
 8'd55:glyph=35'b11111000010001000100010000100001000;
 8'd56:glyph=35'b01110100011000101110100011000101110;
 8'd57:glyph=35'b01110100011000101111000010000101110;
 8'd47:glyph=35'b00001000010001000100010001000010000;
 8'd45:glyph=35'b00000000000000011111000000000000000;
 8'd32:glyph=35'b00000000000000000000000000000000000;
 default:glyph=0;endcase end endfunction

 // Two-step 3px corners share comparisons and reduce slice pressure.
 function roundbox;input [9:0] px,py,l,t,r,b;begin
  roundbox=px>=l && px<r && py>=t && py<b &&
   !(((px<l+10'd1 || px>=r-10'd1)&&(py<t+10'd3 || py>=b-10'd3))||
     ((px<l+10'd3 || px>=r-10'd3)&&(py<t+10'd1 || py>=b-10'd1)));
 end endfunction
 function ball;input [9:0] px,py,cx,cy;reg [9:0] dx,dy;begin
  dx=px-cx+10'd4;dy=py-cy+10'd4;
  ball=dx<10'd8 && dy<10'd8 && !((dx==0 || dx==7)&&(dy==0 || dy==7));
 end endfunction
 wire [9:0] far_phase={1'b0,x[9:1]}+{2'b00,trail_x0[9:2]};
 wire [9:0] near_phase=x+{1'b0,trail_x0[9:1]},road_phase=x+trail_x0;
 wire [4:0] run_dx=x[4:0]^5'd16;
 wire [9:0] run_dy=y+10'd32-{1'b0,ball_y};
 wire [9:0] run_dx0=x-paddle_x,run_dx1=x-ball_x;
 wire head0=RUNNER_DUCK && runner_overhead0,head1=RUNNER_DUCK && runner_overhead1;
 wire obstacle_a=run_dx0<32 && (head0?(y>=200 && y<356):(y>=344 && y<384));
 wire obstacle_b=run_dx1<32 && (head1?(y>=200 && y<356):(y>=328 && y<384));

 wire duck_draw=RUNNER_DUCK && runner_sliding && view_game && selected;
 wire [4:0] duck_dy=y-10'd360;
 wire [8:0] duck_sample={duck_dy,4'b0}+{2'b0,duck_dy,2'b0}+{4'b0,duck_dy};
 wire sprite_area=(!view_game || selected) && (view_game ?
       (x>=128 && x<192 && (duck_draw?(y>=360 && y<384):(run_dy<64 && (state==1 || y<256 || y>=374)))) :
       (x>=416 && x<480 && y>=224 && y<288));
 wire [3:0] sprite_x=view_game?x[5:2]:x[5:2]^4'd8;
 wire [3:0] sprite_y=view_game?(duck_draw?duck_sample[8:5]:run_dy[5:2]):y[5:2]^4'd8;
 wire [1:0] sprite_pose=!view_game?2'd2:state==4?2'd3:duck_draw?2'd0:ball_y<352?2'd2:{1'b0,trail_x0[4]};
 reg [3:0] sprite_rom[0:1023];
 initial $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/runner_sprite.hex",sprite_rom);
 reg [3:0] sprite_a;reg sprite_area_a;
 always @(posedge clk)begin
  sprite_a<=sprite_rom[{sprite_pose,sprite_y,sprite_x}];
  sprite_area_a<=sprite_area;
 end
 function [23:0] sprite_color;input [3:0] c;begin case(c)
  1:sprite_color=24'h18263d;2:sprite_color=24'hb9a5ed;
  3:sprite_color=24'he6ddff;4:sprite_color=24'h24364e;
  5:sprite_color=24'h41617b;6:sprite_color=24'hb9fff0;
  7:sprite_color=24'hffb6c6;8:sprite_color=24'h547f91;
  9:sprite_color=24'h67dcc0;10:sprite_color=24'h359b9d;
  11:sprite_color=24'hd36591;12:sprite_color=24'hffabc4;
  13:sprite_color=24'hffce96;default:sprite_color=0;
 endcase end endfunction
 reg [4:0] style;reg [23:0] base;
 reg [1:0] brick_row;reg row_valid;
 wire [9:0] brick_local_x=x-10'd64;
 wire [2:0] brick_col=brick_local_x[8:6];
 reg [8:0] row_top;
 wire card_side=x>=10'd328;
 wire [9:0] card_x=card_side?x-10'd300:x;
 wire [9:0] demo_x=x-10'd72,demo_y=y-10'd214;
 wire [9:0] paddle_local=x-paddle_x,paddle_glow=x-paddle_x+10'd3;
 wire [9:0] spark_dx=x>=hit_x?x-hit_x:hit_x-x;
 wire [9:0] spark_dy=y>={1'b0,hit_y}?y-{1'b0,hit_y}:{1'b0,hit_y}-y;
 wire [3:0] impact_age=4'd12-hit_timer;
 wire [5:0] shard_x={1'b0,impact_age,1'b0}+6'd6;
 wire [5:0] shard_y={2'b0,impact_age}+6'd4;
 wire [9:0] ball_glow_x=x-ball_x+10'd6,ball_glow_y=y-{1'b0,ball_y}+10'd6;
 wire [9:0] skid_phase=x+{5'd0,trail_x0[4:0]};
 wire [4:0] landing_age=5'd12-{1'b0,trail_y0[3:0]};
 wire [9:0] landing_dx=x>=160?x-10'd160:10'd160-x;
 integer k;
 always @*begin
  style=0;brick_row=0;row_valid=0;row_top=128;
  if(y==50 || y==432)style=2;
  if(!view_game)begin
   // A single reusable card calculation selects one of the two game slots.
   if(roundbox(card_x,y,28,146,312,406))style=1;
   if(roundbox(card_x,y,28,144,312,404))style=card_side==selected?3:2;
   if(roundbox(card_x,y,30,146,310,402))style=card_side==selected?4:5;
   if(roundbox(card_x,y,48,164,144,186))style=card_side?7:6;
   if(roundbox(card_x,y,48,360,292,388))style=3;
   // Deliberately geometric art, shared by the actual game and its launch card.
   if(x>=72 && x<264 && y>=214 && y<262 && demo_x[4:0]<26 && demo_y[3:0]<10)begin
    style=demo_y[5:4]==0?9:demo_y[5:4]==1?3:10;
    if((demo_x[4:0]==0 || demo_x[4:0]==25) && (demo_y[3:0]==0 || demo_y[3:0]==9))style=4;
   end
   if(roundbox(x,y,98,282,226,290))style=6;
   if(roundbox(x,y,98,280,226,286))style=3;
   if(ball(x,y,166,268))style=8;
   // Runner launch art uses the same neon blocks as the live scene.
   if(x>=368 && x<576 && y>=286 && y<289)style=3;
   if(x>=508 && x<534 && y>=254 && y<286)style=10;
   if(x>=510 && x<532 && y>=256 && y<282)style=5;
   if(x>=384 && x<410 && y>=260 && y<263)style=6;
  end else begin
   if(roundbox(x,y,28,62,220,106)||roundbox(x,y,236,62,396,106)||roundbox(x,y,412,62,612,106))style=5;
   if(!selected)begin
   if(roundbox(x,y,28,118,612,444))style=2;
   if(roundbox(x,y,30,120,610,442))begin
    style=1;
    if(x[5:0]==0 || y[5:0]==0)style=12;
   end
   if(y>=128 && y<148)begin row_valid=1;brick_row=0;row_top=128;end
   else if(y>=156 && y<176)begin row_valid=1;brick_row=1;row_top=156;end
   else if(y>=184 && y<204)begin row_valid=1;brick_row=2;row_top=184;end
   else if(y>=212 && y<232)begin row_valid=1;brick_row=3;row_top=212;end
   if(row_valid && x>=64 && x<576 && brick_local_x[5:0]<56 && bricks[{brick_row,brick_col}])begin
    style=brick_row==0?10:brick_row==1?13:brick_row==2?9:3;
    if(y==row_top || (brick_local_x[5:0]==0 && y<row_top+9'd2))style=8;
    if(y==row_top+9'd19)style=brick_row==3?6:14;
    if((brick_local_x[5:0]==0 || brick_local_x[5:0]==55) && (y==row_top || y==row_top+9'd19))style=1;
   end
   if(state==1)begin
    if(ball(x,y,trail_x2,trail_y2))style=15;
    if(ball(x,y,trail_x1,trail_y1))style=16;
    if(ball(x,y,trail_x0,trail_y0))style=6;
   end
   if(roundbox(paddle_glow,y,0,412,94,426))style=15;
   if(roundbox(paddle_local,y,0,414,88,424))style=6;
   if(roundbox(paddle_local,y,0,412,88,420))style=3;
   if(paddle_local>=12 && paddle_local<76 && y==413)style=8;
   if(POLISH && state==1 && ball_glow_x<12 && ball_glow_y<12 &&
      !((ball_glow_x<2 || ball_glow_x>=10)&&(ball_glow_y<2 || ball_glow_y>=10)))style=16;
   if(ball(x,y,ball_x,ball_y))style=3;
   if(x+10'd2>=ball_x && x<ball_x+10'd2 && y+10'd2>=ball_y && y<ball_y+9'd2)style=8;
   if(POLISH && state==1 && hit_timer!=0)begin
    // Four symmetric 2x2 shards share two absolute-coordinate comparisons.
    if(spark_dx[9:1]=={4'd0,shard_x[5:1]} && spark_dy[9:1]=={4'd0,shard_y[5:1]})style=impact_age<4?8:13;
    if((spark_dx=={4'd0,shard_x} && spark_dy<2) ||
       (spark_dy=={4'd0,shard_y} && spark_dx<2))style=impact_age<4?8:9;
   end else if(!POLISH && hit_timer!=0)begin
    if((spark_dx=={6'd0,hit_timer} && spark_dy<2)||
       (spark_dy=={6'd0,hit_timer} && spark_dx<2))style=8;
   end
   if(!selected)for(k=0;k<3;k=k+1)begin
    if(roundbox(x,y,438+k*46,78,462+k*46,92))style=lives>k?3:7;
    if(x>=441+k*46 && x<459+k*46 && y==79 && lives>k)style=8;
   end
   end else begin
    // Quiet dusk palette; two parallax layers, sparse windows and neon road.
    if(x>=30 && x<610 && y>=120 && y<442)begin
     style=18;
     if(y<220 && x[6:0]==24 && y[5:0]==12)style=19;
     if(x>=496 && x<544 && y>=148 && y<196 &&
        !((x<504 || x>=536)&&(y<156 || y>=188)))style=19;
     if(y>=224 && y<360 && y>=10'd296-{4'd0,far_phase[6:5],4'd0})begin
      style=17;
      if(far_phase[3:0]<3 && y[4:0]==12)style=20;
     end
     if(y>=288 && y<384 && y>=10'd352-{5'd0,near_phase[6:5],3'd0})begin
      style=12;
      if(near_phase[3:0]<3 && y[4:0]==20)style=14;
     end
     if(y>=384)style=21;
     if(y>=384 && y<387)style=hit_timer>=8?8:3;
     if(y>=388 && y<390)style=16;
     if(y>=402 && y<405 && road_phase[6:0]<56)style=6;
     if(y>=426 && y<428 && road_phase[6:0]<80)style=15;
     if(x>=138 && x<182 && y>=388 && y<392)style=15;
     if(trail_y0[3:0]!=0 && !trail_y0[4] && state==1)begin
      if(x>=122 && x<140 && y>=379 && y<382)style=3;
      if(x>=180 && x<190 && y>=381 && y<383)style=19;
     end
     if(POLISH && state==1)begin
      // Sparse speed streaks follow scroll: no animation counter or texture.
      if(level>=2 && (y==236 || y==278 || y==314) && near_phase[7:0]<24)style=level==3?20:14;
      if(trail_y0[3:0]!=0 && !trail_y0[4] &&
         landing_dx[9:1]=={4'd0,landing_age} && (y==379 || y==380))style=19;
     end
     if(obstacle_a || obstacle_b)begin
      style=5;
      if((obstacle_a && head0) || (obstacle_b && head1))begin
       // Hanging neon gates leave a clear 28-pixel sliding lane below.
       style=12;
       if(y<204 || y>=352)style=13;
       if((obstacle_a && (run_dx0<3 || run_dx0>=29)) ||
          (obstacle_b && (run_dx1<3 || run_dx1>=29)))style=13;
       if(y[4:0]==8 || y[4:0]==9)style=16;
       if(y>=344 && y<348)style=8;
      end else if(obstacle_a)begin
       if(run_dx0[4:0]<2 || run_dx0[4:0]>=30 || y<347)style=10;
       if(run_dx0[4:0]>=12 && run_dx0[4:0]<20 && y>=354 && y<374)style=10;
      end else begin
       if(run_dx1[4:0]<2 || run_dx1[4:0]>=30 || y<331)style=13;
       if(run_dx1[4:0]>=12 && run_dx1[4:0]<20 && y>=342 && y<372)style=13;
      end
     end
     if(duck_draw && state==1)begin
      if(!POLISH && y>=380 && y<383 && x>=104 && x<128 && x[2:0]<5)style=3;
      if(POLISH && x>=96 && x<140)begin
       if(y>=380 && y<383 && skid_phase[3:0]<5)style=3;
       if((y==374 || y==375) && skid_phase[4:1]==3)style=10;
       if(y==378 && skid_phase[3:1]==5)style=8;
      end
     end
    end
   end
   if(state!=1)begin
    if(roundbox(x,y,142,256,498,374))style=2;
    if(roundbox(x,y,144,258,496,372))style=5;
    if(roundbox(x,y,204,328,436,356))style=3;
   end
  end
 end
 always @*begin
  case(style)
   0:base={8'd9+{6'd0,y[8:7]},8'd16+{6'd0,y[8:7]},8'd28+{5'd0,y[8:6]}};
   1:base=24'h080f1b;
   2:base=24'h293c50;
   3:base=24'h75d3c4;
   4:base=24'h142f39;
   5:base=24'h1a293a;
   6:base=24'h245a52;
   7:base=24'h243549;
   8:base=24'hf2f5f9;
   9:base=24'h7eb8ef;
   10:base=24'hef9d8c;
   11:base=24'h476475;
   12:base=24'h0c1725;
   13:base=24'hb9a3e8;
   14:base=24'h42576b;
   15:base=24'h102b31;
   16:base=24'h18453f;
   17:base=24'h202b46;
   18:base={8'd20+{6'd0,y[8:7]},8'd24+{6'd0,y[8:7]},8'd44+{5'd0,y[8:6]}};
   19:base=24'hc7b9e7;
   20:base=24'h506078;
   21:base=24'h172b35;
   default:base=0;
  endcase
 end
 reg text_area;reg [5:0] line_id;reg [9:0] origin_x,origin_y;
 reg [1:0] text_scale;reg [23:0] ink;
 task label_text;input [5:0] id;input [9:0] l,t,w;input [1:0] scale;input [23:0] color;
 begin if(x>=l && x<l+w && y>=t && y<t+(id==0?10'd16:(10'd7<<scale)))begin
  text_area=1;line_id=id;origin_x=l;origin_y=t;text_scale=scale;ink=color;
 end end endtask
 always @*begin
  text_area=0;line_id=0;origin_x=x;origin_y=y;text_scale=0;ink=24'hf2f5f9;
  label_text(0,28,24,96,0,24'hf2f5f9);
  label_text(9,500,28,112,0,24'ha2afc0);
  if(!view_game)begin
   label_text(30,28,70,192,2,24'hf2f5f9);
   label_text(29,28,112,224,0,24'ha2afc0);
   label_text(3,60,172,72,0,24'h75d3c4);
   label_text(5,360,172,72,0,24'h75d3c4);
   label_text(1,52,310,128,1,24'hf2f5f9);
   label_text(2,52,336,88,0,24'ha2afc0);
   label_text(4,352,310,96,1,24'hf2f5f9);
   label_text(6,352,336,112,0,24'ha2afc0);
   label_text(8,90,368,160,1,24'h102c30);
   label_text(8,390,368,160,1,24'h102c30);
   label_text(7,28,450,104,0,24'ha2afc0);
   label_text(8,532,450,80,0,24'h75d3c4);
  end else begin
   label_text(10,44,70,40,0,24'ha2afc0);
   label_text(31,44,86,64,1,(selected && trail_y0[4])?24'h75d3c4:24'hf2f5f9);
   label_text(11,252,70,40,0,24'ha2afc0);
   label_text(32,348,82,16,1,24'h75d3c4);
   if(POLISH && !selected && combo>=2 && state==1)label_text(37,252,96,64,0,24'hb9a3e8);
   label_text(selected?6'd34:6'd12,428,66,40,0,24'ha2afc0);
   if(selected)label_text(33,440,86,64,1,24'hf2f5f9);
   label_text(selected?6'd35:6'd13,180,458,280,0,24'ha2afc0);
   if(state!=1)begin
    case(state)
     0:begin label_text(14,216,278,208,1,24'hf2f5f9);label_text(selected?6'd36:6'd24,204,306,232,0,24'ha2afc0);label_text(19,240,336,160,1,24'h102c30);end
     2:begin label_text(15,272,278,96,1,24'hf2f5f9);label_text(25,268,306,104,0,24'ha2afc0);label_text(20,232,336,176,1,24'h102c30);end
     3:begin label_text(16,232,278,176,1,24'hf2f5f9);label_text(26,220,306,200,0,24'ha2afc0);label_text(21,248,336,144,1,24'h102c30);end
     4:begin label_text(17,248,278,144,1,24'hef9d8c);label_text(27,240,306,160,0,24'ha2afc0);label_text(22,240,336,160,1,24'h102c30);end
     5:begin label_text(18,264,278,112,1,24'h75d3c4);label_text(28,224,306,192,0,24'ha2afc0);label_text(23,216,336,208,1,24'h102c30);end
     default:begin end
    endcase
   end
  end
 end
 wire [9:0] text_dx=x-origin_x,text_dy=y-origin_y;
 wire [9:0] scaled_dx=text_dx>>text_scale;
 wire [5:0] text_pos=scaled_dx[8:3];
 wire [2:0] text_row=(text_dy>>text_scale);
 wire [2:0] text_col=scaled_dx[2:0];
 reg [23:0] base_a,ink_a;reg [5:0] line_a,pos_a;reg [2:0] row_a,col_a;reg area_a;reg title_half_a;
 reg [23:0] base0,base1,ink0,ink1;reg [7:0] dynamic_ch0,static_ch0;reg static_valid0,dynamic0;
 wire [7:0] ch0=dynamic0?dynamic_ch0:static_valid0?static_ch0:8'd32;
 reg [7:0] text_rom[0:1023];
 initial $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/arcade_text_rom.hex",text_rom);
 wire [15:0] span_a=text_span(line_a);
 wire [9:0] char_address=span_a[15:6]+{4'd0,pos_a}+((line_a==0 && title_half_a)?10'd12:10'd0);
 always @(posedge clk)static_ch0<=text_rom[char_address];
 reg [2:0] row0,col0;reg area0,on1;
 reg font_pixels[0:4095];
 initial $readmemh("D:/FPGA/multimedia_entertainment_screen_sdhs30/rtl/arcade_pixel_font.hex",font_pixels);
 reg font_pixel;
 always @(posedge clk)font_pixel<=font_pixels[{ch0[5:0],row0,col0}];
 wire [5:0] bit_index=6'd35-({3'd0,row0,2'd0}+{3'd0,row0})-{3'd0,col0};
 always @(posedge clk or posedge rst)begin
  if(rst)begin base_a<=0;ink_a<=0;line_a<=0;pos_a<=0;row_a<=0;col_a<=0;area_a<=0;title_half_a<=0;base0<=0;base1<=0;ink0<=0;ink1<=0;dynamic_ch0<=32;static_valid0<=0;dynamic0<=0;row0<=0;col0<=0;area0<=0;on1<=0;rgb<=0;end
  else begin
   title_half_a<=text_dy[3];base_a<=base;ink_a<=ink;line_a<=line_id;pos_a<=text_pos;row_a<=text_row;col_a<=text_col;area_a<=text_area;
   base0<=(sprite_area_a && sprite_a!=0)?sprite_color(sprite_a):base_a;ink0<=ink_a;dynamic_ch0<=letter(line_a,pos_a);static_valid0<=pos_a<span_a[5:0];dynamic0<=line_a==31 || line_a==32 || line_a==33 || (POLISH && line_a==37);row0<=row_a;col0<=col_a;area0<=area_a;
   base1<=base0;ink1<=ink0;on1<=area0;
   rgb<=(on1 && font_pixel)?ink1:base1;
  end
 end
endmodule
