// Fade only after a complete next frame is available. Commit is allowed at black.
module fade_control #(parameter AUTO_CYCLE=0)(input wire clk,rst,vs,frame_pending,mem_ready,
    output reg [4:0] level,output wire swap_allowed,input wire [1:0] requested_mode,output reg [1:0] active_mode);
    localparam IDLE=0,FADE_OUT=1,BLACK=2,FADE_IN=3;
    reg [1:0] state,cycle_mode;
    reg pending_meta,pending_sync,ready_meta,ready_sync,vs_q;
    wire frame_tick=vs_q && !vs;
    assign swap_allowed=(state==BLACK);
    always @(posedge clk or posedge rst)begin
        if(rst)begin pending_meta<=0;pending_sync<=0;ready_meta<=0;ready_sync<=0;vs_q<=1;end
        else begin
            pending_meta<=frame_pending;pending_sync<=pending_meta;
            ready_meta<=mem_ready;ready_sync<=ready_meta;vs_q<=vs;
        end
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin state<=IDLE;level<=16;active_mode<=0;cycle_mode<=0;end
        else if(!ready_sync)begin state<=IDLE;level<=16;active_mode<=0;cycle_mode<=0;end
        else case(state)
            IDLE:begin
                if(AUTO_CYCLE)active_mode<=cycle_mode;
                else case(requested_mode)1:active_mode<=1;2:active_mode<=2;default:active_mode<=0;endcase
                if(pending_sync)state<=FADE_OUT;
            end
            FADE_OUT:if(!pending_sync)state<=FADE_IN;
                else if(frame_tick)begin
                    level<=level-1'b1;
                    if(level==1)state<=BLACK;
                end
            BLACK:if(!pending_sync)begin
                state<=FADE_IN;
                if(AUTO_CYCLE)cycle_mode<=cycle_mode==2 ? 2'd0 : cycle_mode+2'd1;
            end
            FADE_IN:if(frame_tick)begin
                if(level<16)level<=level+1'b1;
                if(level>=15)state<=IDLE;
            end
        endcase
    end
endmodule
