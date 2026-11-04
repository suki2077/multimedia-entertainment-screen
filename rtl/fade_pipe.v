// Gain is 0..16, updated only during vertical blanking. Preserve pipeline alignment.
module fade_pipe(input wire clk,rst,input wire [4:0] level,
    input wire [23:0] rgb_in,input wire hs_in,vs_in,de_in,input wire [9:0] x_in,y_in,
    output reg [23:0] rgb_out,output reg hs_out,vs_out,de_out,output reg [9:0] x_out,y_out,input wire [1:0] mode);
    wire [12:0] r=rgb_in[23:16]*level;
    wire [12:0] g=rgb_in[15:8]*level;
    wire [12:0] b=rgb_in[7:0]*level;
    wire [9:0] edge_x={level,5'd0}+{level,3'd0};
    wire [5:0] blind_height={level,1'b0};
    wire wipe_on=x_in<edge_x;
    wire blind_on={1'b0,y_in[4:0]}<blind_height;
    reg [23:0] effect_rgb;
    always @*begin
        case(mode)
            1:effect_rgb=wipe_on?rgb_in:24'd0;
            2:effect_rgb=blind_on?rgb_in:24'd0;
            default:effect_rgb={r[11:4],g[11:4],b[11:4]};
        endcase
    end
    always @(posedge clk or posedge rst)begin
        if(rst)begin rgb_out<=0;hs_out<=1;vs_out<=1;de_out<=0;x_out<=0;y_out<=0;end
        else begin
            rgb_out<=effect_rgb;
            hs_out<=hs_in;vs_out<=vs_in;de_out<=de_in;x_out<=x_in;y_out<=y_in;
        end
    end
endmodule
