// Synchronize and debounce all switch bits, then apply only in vertical blanking.
module av_controls #(parameter DEBOUNCE_CYCLES=200000)(
    input wire clk,rst,input wire [3:0] switches,input wire vs,
    output reg [1:0] brightness,output reg sound_enable,output reg period_long);
    reg [3:0] meta,sync,candidate,stable;
    reg [17:0] count;
    reg vs_q;
    always @(posedge clk or posedge rst) begin
        if(rst)begin meta<=7;sync<=7;candidate<=7;stable<=7;count<=0;vs_q<=1;brightness<=3;sound_enable<=1;period_long<=0;end
        else begin
            meta<=switches;sync<=meta;vs_q<=vs;
            if(sync!=candidate)begin candidate<=sync;count<=0;end
            else if(count<DEBOUNCE_CYCLES)count<=count+1'b1;
            else stable<=candidate;
            if(vs_q && !vs)begin brightness<=stable[1:0];sound_enable<=stable[2];period_long<=stable[3];end
        end
    end
endmodule
