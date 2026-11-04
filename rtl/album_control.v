// A dwell interval starts only after a complete frame is committed.
// Four consecutive failed candidates stop retries; a successful load clears the count.
module album_control #(
    parameter TICK_CYCLES=71429, HOLD_TICKS=5000, HOLD_TICKS_LONG=10000
)(
    input wire clk,rst,init_done,next_press,prev_press,mode_press,
    input wire period_long,
    input wire swapped,load_failed,fatal_error,input wire [1:0] displayed,
    output reg [1:0] selected,output wire busy,started,loader_reset,
    output reg begin_load,auto_mode,all_failed
);
    localparam WAIT_INIT=0,RESET_LOAD=1,WAIT_LOAD=2,IDLE=3,STOPPED=4;
    reg [2:0] state;
    reg [3:0] reset_count;
    reg [1:0] failures;
    reg forward;
    reg [16:0] tick_count;
    reg [13:0] hold_count;
    reg period_meta,period_sync,period_used;
    wire period_changed=(period_sync!=period_used);
    always @(posedge clk or posedge rst) begin
        if(rst)begin period_meta<=0;period_sync<=0;period_used<=0;end
        else begin period_meta<=period_long;period_sync<=period_meta;period_used<=period_sync;end
    end
    assign busy=(state==WAIT_INIT || state==RESET_LOAD || state==WAIT_LOAD);
    assign started=(state!=WAIT_INIT);
    assign loader_reset=rst || state==WAIT_INIT || state==RESET_LOAD;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=WAIT_INIT;reset_count<=0;failures<=0;forward<=1;
            tick_count<=0;hold_count<=0;selected<=0;begin_load<=0;
            auto_mode<=0;all_failed<=0;
        end else begin
            begin_load<=0;
            if(mode_press && !fatal_error) auto_mode<=~auto_mode;
            if(state!=IDLE || !auto_mode || mode_press || period_changed) begin tick_count<=0;hold_count<=0;end
            case(state)
                WAIT_INIT: if(init_done) begin
                    selected<=0;reset_count<=15;begin_load<=1;state<=RESET_LOAD;
                end
                RESET_LOAD: if(reset_count==0) state<=WAIT_LOAD;
                    else reset_count<=reset_count-1'b1;
                WAIT_LOAD: begin
                    if(swapped) begin failures<=0;all_failed<=0;state<=IDLE;end
                    else if(load_failed) begin
                        if(failures==3) begin
                            all_failed<=1;auto_mode<=0;state<=STOPPED;
                        end else begin
                            failures<=failures+1'b1;
                            selected<=forward ? selected+2'd1 : selected-2'd1;
                            reset_count<=15;begin_load<=1;state<=RESET_LOAD;
                        end
                    end
                end
                IDLE: begin
                    if(next_press || prev_press) begin
                        forward<=next_press;selected<=next_press ? displayed+2'd1 : displayed-2'd1;
                        failures<=0;tick_count<=0;hold_count<=0;
                        reset_count<=15;begin_load<=1;state<=RESET_LOAD;
                    end else if(auto_mode && !mode_press && !period_changed) begin
                        if(tick_count==TICK_CYCLES-1) begin
                            tick_count<=0;
                            if(hold_count==(period_used ? HOLD_TICKS_LONG-1 : HOLD_TICKS-1)) begin
                                hold_count<=0;forward<=1;selected<=displayed+2'd1;
                                reset_count<=15;begin_load<=1;state<=RESET_LOAD;
                            end else hold_count<=hold_count+1'b1;
                        end else tick_count<=tick_count+1'b1;
                    end
                end
                STOPPED: if(!fatal_error && (next_press || prev_press || mode_press)) begin
                    selected<=next_press ? displayed+2'd1 : prev_press ? displayed-2'd1 : selected;
                    forward<=!prev_press;failures<=0;all_failed<=0;
                    reset_count<=15;begin_load<=1;state<=RESET_LOAD;
                end
                default: state<=STOPPED;
            endcase
            if(fatal_error) begin state<=STOPPED;auto_mode<=0;end
        end
    end
endmodule
