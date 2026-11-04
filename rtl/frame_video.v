// Two ping-pong line buffers: memory writes one row while video reads the other.
module frame_video (
    input wire pclk, rst,video_mode,view_reset,
    input wire mem_ready, mem_failed, mem_verified, mem_init,
    input wire mem_ack,
    input wire [8:0] tag_even, tag_odd,
    input wire valid_even, valid_odd,
    output reg req_toggle, output reg [8:0] req_row,
    output wire [10:0] line_raddr, input wire [23:0] line_q,
    output reg hs, vs, de, output wire [23:0] rgb,
    output reg underrun,
    output wire [9:0] pixel_x, pixel_y
);
    reg [9:0] x,y;
    reg ready_m,ready_s,fail_m,fail_s,ack_m,ack_s;
    reg ver_m,ver_s,init_m,init_s;
    reg [8:0] even_m,even_s,odd_m,odd_s;
    reg [1:0] valid_m,valid_s;
    reg display_on;
    reg [23:0] fallback;
    reg use_memory;
    wire active=(x<640 && y<480);
    wire showing=display_on || (x==0 && y==0 && ready_s && !fail_s);
    wire row_ok=y[0] ? (valid_s[1] && odd_s==y[8:0]) :
                              (valid_s[0] && even_s==y[8:0]);
    wire [11:0] video_x={2'b0,x}+{1'b0,x,1'b0};
    assign line_raddr=video_mode?{y[0],1'b0,video_x[10:2]}:{y[0],x};
    assign pixel_x=x; assign pixel_y=y;
    assign rgb=use_memory ? line_q : fallback;
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            ready_m<=0;ready_s<=0;fail_m<=0;fail_s<=0;ack_m<=0;ack_s<=0;
            ver_m<=0;ver_s<=0;init_m<=0;init_s<=0;
            even_m<=0;even_s<=0;odd_m<=0;odd_s<=0;valid_m<=0;valid_s<=0;
        end else begin
            ready_m<=mem_ready; ready_s<=ready_m;
            fail_m<=mem_failed; fail_s<=fail_m;
            ack_m<=mem_ack; ack_s<=ack_m;
            ver_m<=mem_verified;ver_s<=ver_m;init_m<=mem_init;init_s<=init_m;
            even_m<=tag_even;even_s<=even_m;odd_m<=tag_odd;odd_s<=odd_m;
            valid_m<={valid_odd,valid_even};valid_s<=valid_m;
        end
    end
    always @(posedge pclk or posedge rst) begin
        if (rst) begin
            x<=0;y<=0;hs<=1;vs<=1;de<=0;
            req_toggle<=0;req_row<=0;display_on<=0;underrun<=0;
            fallback<=0;use_memory<=0;
        end else begin
            if (x==799) begin x<=0; if(y==524)y<=0;else y<=y+1'b1;end
            else x<=x+1'b1;
            hs<=~(x>=656 && x<752);vs<=~(y>=490 && y<492);de<=active;
            if (x==0 && y==0) display_on<=ready_s && !fail_s;
            if(view_reset)begin display_on<=0;underrun<=0;end
            if (fail_s) display_on<=0;
            // Request next row one full scanline before it is needed.
            if (x==0 && ready_s && !fail_s && (y<479 || y==524)) begin
                if (ack_s==req_toggle) begin
                    req_row<=(y==524) ? 9'd0 : y[8:0]+1'b1;
                    req_toggle<=~req_toggle;
                end else if(display_on) underrun<=1;
            end
            if(active && display_on && !row_ok && !fail_s) underrun<=1;
            use_memory<=active && showing && row_ok && !fail_s && !view_reset;
            // Diagnostic screen: blue waiting, red failure, magenta row miss.
            if(!active) fallback<=0;
            else if(fail_s) fallback<=24'hc00000;
            else if(display_on && !row_ok) fallback<=24'hff00ff;
            else fallback<=24'h001060;

        end
    end
endmodule
