`timescale 1ns/1ps
module tb_volume_music;
    reg mc=0,pc=0,rst=1;always #7 mc=~mc;always #20 pc=~pc;
    reg [3:0] restart=15;wire arst=rst || restart!=0;
    wire aq,av,ae,aw,done,failed,sv,sr,rv,pop,playing,under,audio_valid,acr,sreset,iq_wait;
    wire [31:0] alba,sample,fd,sd_lba;wire [7:0] err;wire [23:0] left_data,right_data;
    wire [12:0] wl,rl;
    reg iq=0,ib=0,sd_valid=0,sd_end=0;reg [7:0] sd_byte=0;
    wire iv,ie,sd_req;
    integer cycle=0,offset=0,index=-1,lo,hi,mid,n=0,eofs=0,image_sectors=0,image_bytes=0;
    reg active=0;reg [31:0] current;
    wire image_reset=rst || (cycle%500000<15);
    reg [31:0] info[0:9],lbas[0:255],expected[0:4096],word;
    reg [7:0] disk[0:131071];
    wire [2:0] volume=(n/750)%5;
    integer expected_left,expected_right;
    wire sound=!(n>=4500 && n<5000);
    sd_read_arbiter #(.TIMEOUT(500000)) arb(mc,rst,1'b1,image_reset,iq,32'hdead0000,arst,aq,alba,wl<1536,
        iq_wait,aw,iv,ie,av,ae,sd_valid,sd_end,sd_req,sd_lba,sreset);
    fat32_media_stream #(.IO_TIMEOUT(2000000)) reader(.clk(mc),.rst(arst),.enable(1'b1),.sd_ready(1'b1),.io_wait(aw),.video_mode(1'b0),.sector_req(aq),.sector_lba(alba),.byte_valid(av),.byte_data(sd_byte),.sector_end(ae),.sample_valid(sv),.sample_ready(sr),.sample_data(sample),.done(done),.failed(failed),.error_code(err),.debug_state());
    audio_fifo fifo(mc,pc,rst,sv,sample,sr,pop,rv,fd,wl,rl,1'b0,1'b0);
    pcm_player player(pc,rst,sound,rv,fd,rl,pop,audio_valid,acr,left_data,right_data,playing,under,volume);
    always @(posedge mc)begin
        cycle<=cycle+1;sd_valid<=0;sd_end<=0;iq<=0;
        if(rst)restart<=15;
        else if(restart!=0)restart<=restart-1'b1;
        else if(done)begin restart<=15;eofs=eofs+1;end
        if(image_reset)begin ib<=0;image_bytes=0;end
        else begin
            if(!ib)begin iq<=1;ib<=1;image_bytes=0;end
            if(iv)image_bytes=image_bytes+1;
            if(ie)begin
                if(image_bytes!=512)$fatal(1,"shared image sector count %d",image_bytes);
                ib<=0;image_sectors=image_sectors+1;
            end
        end
        if(!rst)begin
            if(failed)$fatal(1,"shared WAV error %h",err);
            if(sreset)$fatal(1,"image switch reset the card");
            if(sd_req)begin
                if(active)$fatal(1,"shared transaction overlap");
                current=sd_lba;offset=0;active=1;
                if(sd_lba!=32'hdead0000)begin
                    lo=0;hi=info[0]-1;index=-1;
                    while(lo<=hi)begin mid=(lo+hi)/2;if(lbas[mid]==sd_lba)begin index=mid;lo=hi+1;end else if(lbas[mid]<sd_lba)lo=mid+1;else hi=mid-1;end
                    if(index<0)$fatal(1,"shared bad LBA %d",sd_lba);
                end
            end else if(active && cycle%96==0)begin
                if(offset<512)begin
                    sd_valid<=1;sd_byte<=(current==32'hdead0000)?8'h55:disk[index*512+offset];offset=offset+1;
                end else begin active=0;sd_end<=1;end
            end
        end
    end
    always @(posedge pc)if(!rst)begin
        if(under)$fatal(1,"music underflow while image sectors busy");
        if(pop)begin
            word=expected[n%4097];
            if(fd!==word)$fatal(1,"shared FIFO order sample=%d got=%h expected=%h",n,fd,word);
            if(sound)begin
                expected_left=$signed(word[15:0]);expected_right=$signed(word[31:16]);
                expected_left=expected_left*volume*64;expected_right=expected_right*volume*64;
                #1;if($signed(left_data)!==expected_left || $signed(right_data)!==expected_right)$fatal(1,"shared HDMI PCM mismatch");
            end else begin #1;if(left_data!=0 || right_data!=0)$fatal(1,"shared mute");end
            n=n+1;
            if(n==9000)begin
                if(eofs<2 || image_sectors<5)$fatal(1,"loop/fairness not exercised");
                $display("PASS all five gains during 9000 PCM frames across %d EOF loops, %d image sectors, repeated image resets, mute continuity, zero underruns",eofs,image_sectors);$finish;
            end
        end
    end
    initial begin
        $readmemh("sim/fixtures/chunks/info.hex",info);
        $readmemh("sim/fixtures/chunks/lbas.hex",lbas,0,info[0]-1);
        $readmemh("sim/fixtures/chunks/data.hex",disk,0,info[0]*512-1);
        $readmemh("sim/fixtures/chunks/expected.hex",expected);
        #101;rst=0;
    end
    initial begin #400000000;$fatal(1,"shared playback timeout n=%d",n);end
endmodule

