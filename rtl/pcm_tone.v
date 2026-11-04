// Direct PCM synthesis, no I2S loopback or independent audio clock.
// 25 MHz * 6/3125 = exactly 48 kHz average; 48 samples = 1 kHz sine.
// HDMI ACR: Fs=F_TMDS*N/(128*CTS), N=6144, CTS=25000.
module pcm_tone(input wire clk,rst,sound_enable,output reg audio_valid,
    output reg [23:0] left_data,right_data,output reg acr_valid);
    reg [11:0] accumulator;
    reg [5:0] phase;
    function [23:0] sine;
        input [5:0] p;
        begin case(p)
            6'd0: sine=24'h000000;
            6'd1: sine=24'h0216a3;
            6'd2: sine=24'h04241f;
            6'd3: sine=24'h061f79;
            6'd4: sine=24'h080000;
            6'd5: sine=24'h09bd7d;
            6'd6: sine=24'h0b504f;
            6'd7: sine=24'h0cb193;
            6'd8: sine=24'h0ddb3d;
            6'd9: sine=24'h0ec836;
            6'd10: sine=24'h0f746f;
            6'd11: sine=24'h0fdcf5;
            6'd12: sine=24'h100000;
            6'd13: sine=24'h0fdcf5;
            6'd14: sine=24'h0f746f;
            6'd15: sine=24'h0ec836;
            6'd16: sine=24'h0ddb3d;
            6'd17: sine=24'h0cb193;
            6'd18: sine=24'h0b504f;
            6'd19: sine=24'h09bd7d;
            6'd20: sine=24'h080000;
            6'd21: sine=24'h061f79;
            6'd22: sine=24'h04241f;
            6'd23: sine=24'h0216a3;
            6'd24: sine=24'h000000;
            6'd25: sine=24'hfde95d;
            6'd26: sine=24'hfbdbe1;
            6'd27: sine=24'hf9e087;
            6'd28: sine=24'hf80000;
            6'd29: sine=24'hf64283;
            6'd30: sine=24'hf4afb1;
            6'd31: sine=24'hf34e6d;
            6'd32: sine=24'hf224c3;
            6'd33: sine=24'hf137ca;
            6'd34: sine=24'hf08b91;
            6'd35: sine=24'hf0230b;
            6'd36: sine=24'hf00000;
            6'd37: sine=24'hf0230b;
            6'd38: sine=24'hf08b91;
            6'd39: sine=24'hf137ca;
            6'd40: sine=24'hf224c3;
            6'd41: sine=24'hf34e6d;
            6'd42: sine=24'hf4afb1;
            6'd43: sine=24'hf64283;
            6'd44: sine=24'hf80000;
            6'd45: sine=24'hf9e087;
            6'd46: sine=24'hfbdbe1;
            6'd47: sine=24'hfde95d;
            default:sine=0;
        endcase end
    endfunction
    always @(posedge clk or posedge rst) begin
        if(rst) begin accumulator<=0;phase<=0;audio_valid<=0;acr_valid<=0;left_data<=0;right_data<=0;end
        else begin
            audio_valid<=0;acr_valid<=0;
            if(accumulator>=12'd3119) begin
                accumulator<=accumulator-12'd3119;audio_valid<=1;
                left_data<=sound_enable ? sine(phase) : 24'd0;
                right_data<=sound_enable ? sine(phase) : 24'd0;
                if(phase==47)begin phase<=0;acr_valid<=1;end else phase<=phase+1'b1;
            end else accumulator<=accumulator+12'd6;
        end
    end
endmodule
