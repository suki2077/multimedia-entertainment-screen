// Gray-pointer dual-clock FIFO, 2048 stereo frames (42ms at 48kHz).
// Registered RAM head has one settling cycle after each read pop.
module audio_fifo #(parameter A=11)(input wire wclk,rclk,rst,
    input wire wvalid,input wire [31:0] wdata,output wire wready,
    input wire rpop,output wire rvalid,output reg [31:0] rdata,
    output wire [A:0] wlevel,rlevel,input wire wflush,rflush);
    reg [2:0] wreset_pipe,rreset_pipe;
    wire wrst=wreset_pipe[2],rrst=rreset_pipe[2];
    always @(posedge wclk or posedge rst)begin
        if(rst)wreset_pipe<=7;else wreset_pipe<={wreset_pipe[1:0],1'b0};
    end
    always @(posedge rclk or posedge rst)begin
        if(rst)rreset_pipe<=7;else rreset_pipe<={rreset_pipe[1:0],1'b0};
    end
    reg [31:0] mem[0:(1<<A)-1];
    reg [A:0] wb,wg,rb,rg,rgm,rgs,wgm,wgs;
    reg settling;
    function [A:0] binary;
        input [A:0] gray;integer i;
        begin binary[A]=gray[A];for(i=A-1;i>=0;i=i-1)binary[i]=binary[i+1]^gray[i];end
    endfunction
    assign wready=!wrst && !wflush && wg!={~rgs[A:A-1],rgs[A-2:0]};
    assign rvalid=!rrst && !rflush && (rg!=wgs)&&!settling;
    assign wlevel=wb-binary(rgs);
    assign rlevel=binary(wgs)-rb;
    always @(posedge wclk)if(!rst && !wflush && wvalid && wready)mem[wb[A-1:0]]<=wdata;
    always @(posedge rclk)rdata<=mem[rb[A-1:0]];
    always @(posedge wclk or posedge rst)begin
        if(rst || wrst || wflush)begin wb<=0;wg<=0;rgm<=0;rgs<=0;end
        else begin
            rgm<=rg;rgs<=rgm;
            if(wvalid && wready)begin wb<=wb+1'b1;wg<=((wb+1'b1)>>1)^(wb+1'b1);end
        end
    end
    always @(posedge rclk or posedge rst)begin
        if(rst || rrst || rflush)begin rb<=0;rg<=0;wgm<=0;wgs<=0;settling<=0;end
        else begin
            wgm<=wg;wgs<=wgm;settling<=0;
            if(rpop && rvalid)begin rb<=rb+1'b1;rg<=((rb+1'b1)>>1)^(rb+1'b1);settling<=1;end
        end
    end
endmodule
