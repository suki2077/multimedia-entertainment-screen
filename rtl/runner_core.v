// Register-only runner. All motion commits in vertical blank; audio changes
// lighting only, never the obstacle timing. No RAM, multiplier or FFT.
module runner_core #(parameter DUCK=0)(input wire clk,rst,vs,active,jump,confirm,input wire [3:0] energy,
 output reg [2:0] state,output reg [1:0] level,output reg [15:0] score,best,
 output reg [8:0] runner_y,output reg [9:0] obstacle0,output reg [9:0] obstacle1,output reg [9:0] scroll,
 output reg [3:0] glow,output reg [4:0] feedback,
 input wire slide,output reg sliding,output reg overhead0,overhead1);
 localparam READY=0,PLAY=1,PAUSE=2,OVER=4;
 reg vs_q,pending_confirm;reg [2:0] jump_buffer,passed;
 reg signed [5:0] velocity;
 reg [6:0] course;
 // Vary the recovery interval, never repeat the previous required action.
 wire [9:0] gap=course[1]?10'd448:course[0]?10'd384:10'd320;
 wire frame_tick=vs_q && !vs;
 wire [9:0] speed=level==1?10'd4:level==2?10'd5:10'd6;
 wire [9:0] nx0=obstacle0-speed;
 wire [9:0] nx1=obstacle1-speed;
 wire recycle0=obstacle0>=960 && obstacle0<992;
 wire recycle1=obstacle1>=960 && obstacle1<992;
 wire signed [10:0] proposed_y=$signed({2'b00,runner_y})+{{5{velocity[5]}},velocity};
 wire [8:0] next_y=(proposed_y >= 11'sd352) ? 9'd352 : proposed_y[8:0];
 // Inset hitbox makes near-edge jumps forgiving. Horizontal tests cannot
 // wrap around at x=1023, because distant columns are rejected first.
 wire crouch=DUCK && slide && next_y==352;
 wire [8:0] hit_top=crouch?9'd366:next_y-9'd20;
 wire [8:0] hit_bottom=next_y+9'd30;
 wire hit0=DUCK && overhead0 ? (hit_top<356 && hit_bottom>200) : hit_bottom>344;
 wire hit1=DUCK && overhead1 ? (hit_top<356 && hit_bottom>200) : hit_bottom>328;
 wire hit=((nx0<172 && nx0+10'd29>148 && hit0) ||
           (nx1<172 && nx1+10'd29>148 && hit1));
 wire passed_column=(obstacle0>=128 && obstacle0<960 && nx0<128) ||
                    (obstacle1>=128 && obstacle1<960 && nx1<128);
 task new_run;
  begin level<=1;score<=0;runner_y<=352;velocity<=0;
   obstacle0<=600;obstacle1<=920;sliding<=0;overhead0<=0;overhead1<=DUCK;scroll<=0;passed<=0;jump_buffer<=0;course<=7'h5d;feedback<=0;
  end
 endtask
 task add_score;
  begin
   if(score[7:4]!=9)score[7:4]<=score[7:4]+1'b1;
   else begin score[7:4]<=0;
    if(score[11:8]!=9)score[11:8]<=score[11:8]+1'b1;
    else begin score[11:8]<=0;if(score[15:12]!=9)score[15:12]<=score[15:12]+1'b1;else score<=16'h9990;end
   end
  end
 endtask
 always @(posedge clk or posedge rst)begin
  if(rst)begin vs_q<=1;pending_confirm<=0;state<=READY;best<=0;glow<=0;new_run;end
  else begin
   vs_q<=vs;
   if(score>best)best<=score;
   if(!active)begin state<=READY;pending_confirm<=0;glow<=0;new_run;end
   else begin
    if(confirm)pending_confirm<=1;
    if(jump && state==PLAY && !(DUCK && slide))jump_buffer<=6;
    if(frame_tick)begin
     pending_confirm<=0;
     if(energy>glow)glow<=energy;else if(glow!=0)glow<=glow-1'b1;
     if(pending_confirm || confirm)begin
      jump_buffer<=0;
      case(state)
       READY:state<=PLAY;
       PLAY:state<=PAUSE;
       PAUSE:state<=PLAY;
       OVER:begin new_run;state<=PLAY;end
       default:state<=READY;
      endcase
     end else if(state==PLAY)begin
      if(hit)begin state<=OVER;jump_buffer<=0;feedback<=0;sliding<=0;end
      else begin
       sliding<=crouch;
       // Each slot recycles behind the other. Their initial jump/slide types
       // remain fixed, so spatial order guarantees alternation without a
       // dynamic type register or extra renderer/collision multiplexers.
       obstacle0<=recycle0 ? obstacle1+gap : nx0;
       obstacle1<=recycle1 ? obstacle0+gap : nx1;
       if(recycle0 || recycle1)course<={course[5:0],course[6]^course[5]};
       if(feedback==16)feedback<=0;
       else if(feedback!=0)feedback<=feedback-1'b1;
       if(runner_y<352 && next_y==352)feedback<=12;
       scroll<=scroll+speed;
       runner_y<=next_y;
       if((jump_buffer!=0 || jump) && runner_y==352 && !(DUCK && slide))begin velocity<=-15;jump_buffer<=0;end
       else begin
        if(next_y==352)velocity<=0;else velocity<=velocity+1'b1;
        if(DUCK && slide && next_y==352)jump_buffer<=0;
        else if(jump_buffer!=0)jump_buffer<=jump_buffer-1'b1;
       end
       if(passed_column)begin
        add_score;passed<=passed+1'b1;feedback<=28;
        if(passed==7 && level!=3)level<=level+1'b1;
       end
      end
     end
    end
   end
  end
 end
endmodule
