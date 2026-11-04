// One stage: delay sync and coordinates together with the scaled RGB pixel.
module brightness_pipe(input wire clk,rst,input wire [1:0] level,
    input wire [23:0] rgb_in,input wire hs_in,vs_in,de_in,input wire [9:0] x_in,y_in,
    output reg [23:0] rgb_out,output reg hs_out,vs_out,de_out,output reg [9:0] x_out,y_out);
    function [7:0] scale;
        input [7:0] v;input [1:0] l;reg [9:0] triple;
        begin
            triple=({2'b0,v}<<1)+{2'b0,v};
            case(l)
                0:scale=v>>2;
                1:scale=v>>1;
                2:scale=triple[9:2];
                3:scale=v;
            endcase
        end
    endfunction
    always @(posedge clk or posedge rst) begin
        if(rst)begin rgb_out<=0;hs_out<=1;vs_out<=1;de_out<=0;x_out<=0;y_out<=0;end
        else begin
            rgb_out<={scale(rgb_in[23:16],level),scale(rgb_in[15:8],level),scale(rgb_in[7:0],level)};
            hs_out<=hs_in;vs_out<=vs_in;de_out<=de_in;x_out<=x_in;y_out<=y_in;
        end
    end
endmodule
