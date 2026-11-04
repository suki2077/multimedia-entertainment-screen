// Register error selection inputs before crossing clocks; select the message in video domain.
module music_error_status(input wire mclk,pclk,mrst,vrst,
    input wire mem_failed,image_failed,all_failed,wav_failed,input wire [7:0] image_code,wav_code,
    input wire underrun,output wire failed,output wire [7:0] code);
    reg [19:0] source_status,meta,status;
    always @(posedge mclk or posedge mrst)begin
        if(mrst)source_status<=0;
        else source_status<={mem_failed,image_failed,all_failed,wav_failed,image_code,wav_code};
    end
    always @(posedge pclk or posedge vrst)begin
        if(vrst)begin meta<=0;status<=0;end
        else begin meta<=source_status;status<=meta;end
    end
    assign failed=(|status[19:16]) || underrun;
    assign code=status[19]?8'h0a:status[17]?8'h0b:status[18]?status[15:8]:status[16]?(8'h10|status[7:0]):8'h19;
endmodule
