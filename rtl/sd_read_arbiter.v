// One queued request per client. Never preempt an SD sector.
// Audio gets priority below the watermark; otherwise image requests take priority.
module sd_read_arbiter #(parameter TIMEOUT=17857143)(input wire clk,rst,sd_ready,
    input wire image_reset,image_req,input wire [31:0] image_lba,
    input wire audio_reset,audio_req,input wire [31:0] audio_lba,input wire audio_urgent,
    output wire image_wait,audio_wait,output wire image_valid,image_end,audio_valid,audio_end,
    input wire sd_valid,sd_end,output reg sd_req,output reg [31:0] sd_lba,output wire sd_reset);
    reg ip,ap,active,owner,dropping,timeout_end;
    reg [31:0] ilba,alba;
    reg [24:0] watchdog;
    reg [3:0] gap,recovery;
    assign sd_reset=rst || recovery!=0;
    assign image_wait=(!sd_ready || recovery!=0 || (ip && (!active || owner)));
    assign audio_wait=(!sd_ready || recovery!=0 || (ap && (!active || !owner)));
    assign image_valid=active && !owner && !dropping && !image_reset && sd_valid;
    assign audio_valid=active && owner && !dropping && !audio_reset && sd_valid;
    assign image_end=active && !owner && !dropping && !image_reset && (sd_end || timeout_end);
    assign audio_end=active && owner && !dropping && !audio_reset && (sd_end || timeout_end);
    always @(posedge clk or posedge rst)begin
        if(rst)begin ip<=0;ap<=0;active<=0;owner<=0;dropping<=0;timeout_end<=0;ilba<=0;alba<=0;sd_req<=0;sd_lba<=0;watchdog<=0;gap<=0;recovery<=0;end
        else begin
            sd_req<=0;timeout_end<=0;
            if(recovery!=0)recovery<=recovery-1'b1;
            if(image_reset)begin ip<=0;if(active && !owner)dropping<=1;end
            else if(image_req)begin ip<=1;ilba<=image_lba;end
            if(audio_reset)begin ap<=0;if(active && owner)dropping<=1;end
            else if(audio_req)begin ap<=1;alba<=audio_lba;end
            if(active)begin
                if(sd_end || timeout_end)begin active<=0;gap<=15;watchdog<=0;end
                else if(watchdog>=TIMEOUT)begin timeout_end<=1;recovery<=15;watchdog<=0;end
                else watchdog<=watchdog+1'b1;
            end else if(gap!=0)gap<=gap-1'b1;
            else if(sd_ready && recovery==0)begin
                if(ap && !audio_reset && (audio_urgent || !ip || image_reset))begin
                    sd_req<=1;sd_lba<=alba;owner<=1;ap<=0;active<=1;dropping<=0;watchdog<=0;
                end else if(ip && !image_reset)begin
                    sd_req<=1;sd_lba<=ilba;owner<=0;ip<=0;active<=1;dropping<=0;watchdog<=0;
                end
            end
        end
    end
endmodule
