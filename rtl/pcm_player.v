module pcm_player #(parameter PREFILL=1536,PAUSE=0)(input wire clk,rst,sound_enable,
    input wire fifo_valid,input wire [31:0] fifo_data,input wire [12:0] fifo_level,
    output wire fifo_pop,output reg audio_valid,acr_valid,
    output reg [23:0] left_data,right_data,output reg playing,underrun,input wire [2:0] volume,input wire paused);
    // Signed 24-bit output preserves fractional precision of 16-bit source samples.
    // No gain exceeds unity, including the most negative input sample.
    function [23:0] scale_sample;
        input [15:0] sample;input [2:0] level;reg signed [23:0] full;
        begin full=$signed({sample,8'd0});case(level)
            4:scale_sample=full;
            3:scale_sample=full-(full>>>2);
            2:scale_sample=full>>>1;
            1:scale_sample=full>>>2;
            default:scale_sample=0;
        endcase end
    endfunction
    reg [11:0] accumulator;
    reg [5:0] sample_count;
    wire tick=(accumulator>=3119);
    wire advance=!(PAUSE && paused);
    assign fifo_pop=tick && playing && fifo_valid && advance;
    always @(posedge clk or posedge rst)begin
        if(rst)begin accumulator<=0;sample_count<=0;audio_valid<=0;acr_valid<=0;left_data<=0;right_data<=0;playing<=0;underrun<=0;end
        else begin
            audio_valid<=0;acr_valid<=0;
            if(!playing && fifo_level>=PREFILL)playing<=1;
            if(tick)begin
                accumulator<=accumulator-3119;audio_valid<=1;
                if(sample_count==47)begin sample_count<=0;acr_valid<=1;end else sample_count<=sample_count+1'b1;
                if(!advance)begin left_data<=0;right_data<=0;end
                else if(playing && fifo_valid)begin
                    left_data<=sound_enable?scale_sample(fifo_data[15:0],volume):24'd0;
                    right_data<=sound_enable?scale_sample(fifo_data[31:16],volume):24'd0;
                end else begin
                    left_data<=0;right_data<=0;
                    if(playing)begin playing<=0;underrun<=1;end
                end
            end else accumulator<=accumulator+6;
        end
    end
endmodule
