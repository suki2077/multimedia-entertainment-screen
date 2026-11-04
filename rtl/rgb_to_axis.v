// The HDMI core requires contiguous line pixels. LAST must coincide with pixel 639.
module rgb_to_axis(input wire clk,rst,vs,de,input wire [23:0] rgb,
    output reg user,valid,last,output reg [23:0] data);
    reg frame_arm,vs_q;
    reg [9:0] column;
    always @(posedge clk or posedge rst)begin
        if(rst)begin frame_arm<=1;vs_q<=1;column<=0;user<=0;valid<=0;last<=0;data<=0;end
        else begin
            vs_q<=vs;user<=0;valid<=de;last<=0;data<=rgb;
            if(vs_q && !vs)frame_arm<=1;
            if(de)begin
                if(frame_arm && column==0)begin user<=1;frame_arm<=0;end
                last<=(column==639);
                if(column==639)column<=0;else column<=column+1'b1;
            end else column<=0;
        end
    end
endmodule
