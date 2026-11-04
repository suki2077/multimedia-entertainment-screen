module tf_console_hdmi (
    input wire sys_clk, sys_rst_n, key_next_n, key_prev_n, key_mode_n,
    input wire [3:0] switches,
    input wire uart_rx,output wire uart_tx,
    input wire voice_rx,
    output wire HDMI_DDC_SCL,inout wire HDMI_DDC_SDA,
    output wire sd_ncs,sd_dclk,sd_mosi,input wire sd_miso,
    output wire HDMI_CLK_P, HDMI_D2_P, HDMI_D1_P, HDMI_D0_P,
    output wire HDMI_CLK_P1, HDMI_D2_P1, HDMI_D1_P1, HDMI_D0_P1
);
    wire pclk, serial_clk, vlock;
    wire unused100, mclk, mclk_shift, mlock;
    clk_wize u_video_pll(.refclk(sys_clk),.reset(~sys_rst_n),
        .clk0_out(serial_clk),.clk1_out(pclk),.locked(vlock));
    sys_pll u_mem_pll(.refclk(sys_clk),.reset(~sys_rst_n),.extlock(mlock),
        .clk0_out(unused100),.clk1_out(mclk),.clk2_out(mclk_shift));
    wire clocks_ready=sys_rst_n & vlock & mlock;
    reg [21:0] startup_count;
    reg [3:0] pixel_reset;
    reg mrst;
    wire vrst=~pixel_reset[3];
    always @(posedge mclk or negedge clocks_ready) begin
        if(!clocks_ready)begin startup_count<=0;mrst<=1;end
        else begin
            if(startup_count<22'd1428572) startup_count<=startup_count+1'b1;
            mrst<=(startup_count<22'd1428571);
        end
    end
    always @(posedge pclk or negedge clocks_ready) begin
        if(!clocks_ready) pixel_reset<=0;
        else pixel_reset<={pixel_reset[2:0],1'b1};
    end
    wire init_done,refresh_busy,sdr_busy,wr_en,rd_en,rd_valid;
    wire [20:0] wr_addr,rd_addr;
    wire [31:0] wr_data,rd_data;
    sdram u_sdram(.Clk(mclk),.Clk_sft(mclk_shift),.Rst(mrst),
        .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh_busy),.Sdr_busy(sdr_busy),
        .App_wr_en(wr_en),.App_wr_addr(wr_addr),.App_wr_dm(4'b0000),.App_wr_din(wr_data),
        .App_rd_en(rd_en),.App_rd_addr(rd_addr),.Sdr_rd_en(rd_valid),.Sdr_rd_dout(rd_data));
    reg ack_m,ready_m,failed_m,verified_m,ve_m,vo_m,photo_good_m,pending_photo_m;
    reg [8:0] tag_even_m,tag_odd_m;
    wire req,ack,we,verified,ready,failed,valid_even,valid_odd,underrun;
    wire swap_allowed,frame_pending;
    wire [8:0] req_row,tag_even,tag_odd;
    wire [10:0] line_waddr,line_raddr;
    wire [23:0] line_wdata,line_q,rgb,rgb_raw,rgb_status,rgb_bright,rgb_av,rgb_params,rgb_faded;
    wire [9:0] vx,vy;
    wire [23:0] video_hud;
    wire hs,vs,de;
    wire sd_ready,sec_req,sec_valid,sec_end,group_valid,group_ready,load_done,load_failed;
    wire [31:0] sec_lba;
    wire [7:0] sec_byte,load_error;
    wire [20:0] group_addr;
    wire [127:0] group_data;
    wire next_press,prev_press,period_long;
    key_press u_next(.clk(mclk),.rst(mrst),.key_n(key_next_n),.pressed(next_press));
    key_press u_prev(.clk(mclk),.rst(mrst),.key_n(key_prev_n),.pressed(prev_press));
    wire [4:0] selected,displayed;
    wire busy,started,begin_load,swapped,loader_reset,auto_mode,all_failed,mode_press;
    wire confirm_short,home_long,ui_changed;
    wire [2:0] app_page;
    wire [1:0] home_selected,settings_selected,setting_command;
    wire video_paused,video_owner,switching,quiescing;
    wire library_open,library_press,file_restart;
    wire [2:0] library_cursor,music_selected,video_selected;
    wire catalog_entry,catalog_done;wire [2:0] catalog_index;wire [87:0] catalog_name;wire [3:0] catalog_count;
    reg [3:0] music_count,video_count;reg music_list_ready,video_list_ready;
    wire library_ready=(app_page==4?video_list_ready:music_list_ready) && !quiescing;
    library_switch u_library_switch(.clk(mclk),.rst(mrst),.sw_n(switches[3]),.requested(library_press));
    always @(posedge mclk or posedge mrst)begin
     if(mrst)begin music_count<=0;video_count<=0;music_list_ready<=0;video_list_ready<=0;end
     else if(switching)begin music_list_ready<=0;video_list_ready<=0;end
     else if(catalog_done)begin
      if(video_owner)begin video_count<=catalog_count;video_list_ready<=1;end
      else begin music_count<=catalog_count;music_list_ready<=1;end
     end
    end
    media_owner #(.RESTARTABLE(1)) u_owner(.clk(mclk),.rst(mrst),.want_video(app_page==4),.restart(file_restart && app_page==4),.video_owner(video_owner),.switching(switching),.quiescing(quiescing));
    wire song_restart_request=file_restart && !video_owner && app_page!=4;
    reg [4:0] song_restart_hold;
    always @(posedge mclk or posedge mrst)begin
      if(mrst)song_restart_hold<=0;
      else if(song_restart_request)song_restart_hold<=31;
      else if(song_restart_hold!=0)song_restart_hold<=song_restart_hold-1'b1;
    end
    wire song_restarting=song_restart_hold!=0;
    reg song_restart_meta,song_restart_pixel;
    always @(posedge pclk or posedge vrst)begin
      if(vrst)begin song_restart_meta<=0;song_restart_pixel<=0;end
      else begin song_restart_meta<=song_restarting;song_restart_pixel<=song_restart_meta;end
    end
    wire photo_reset=mrst || switching || video_owner;
    wire video_reset=mrst || switching || !video_owner;
    reg owner_meta,owner_pixel,switch_meta,switch_pixel,pause_meta,pause_pixel,quiet_meta,quiet_pixel;
    always @(posedge pclk or posedge vrst)begin
      if(vrst)begin quiet_meta<=0;quiet_pixel<=0;owner_meta<=0;owner_pixel<=0;switch_meta<=0;switch_pixel<=0;pause_meta<=0;pause_pixel<=0;end
      else begin quiet_meta<=quiescing;quiet_pixel<=quiet_meta;owner_meta<=video_owner;owner_pixel<=owner_meta;switch_meta<=switching;switch_pixel<=switch_meta;pause_meta<=video_paused || (library_open && app_page==4);pause_pixel<=pause_meta;end
    end
    wire photo_pixel_reset=vrst || switch_pixel || owner_pixel;
    wire video_pixel_reset=vrst || switch_pixel || !owner_pixel;
    wire p_wr_en,p_rd_en,p_we,p_ack,p_ready,p_failed,p_verified,p_valid_even,p_valid_odd;
    wire [20:0] p_wr_addr,p_rd_addr;
    wire [31:0] p_wr_data;
    wire [10:0] p_line_waddr;
    wire [23:0] p_line_wdata;
    wire [8:0] p_tag_even,p_tag_odd;
    wire v_wr_en,v_rd_en,v_we,v_ack,v_ready,v_valid_even,v_valid_odd;
    wire [20:0] v_wr_addr,v_rd_addr;
    wire [31:0] v_wr_data,v_line_wdata,v_frames,v_late;
    wire [10:0] v_line_waddr;
    wire [8:0] v_tag_even,v_tag_odd;
    wire v_pending,v_frame_toggle,v_done,v_failed,v_req,v_stream_valid,v_stream_ready;
    wire [31:0] v_lba,v_stream_data,v_video_data;
    wire [7:0] v_error;
    wire v_video_valid,v_video_ready,v_mono_valid,v_mono_ready,v_pair_valid,v_pair_ready;
    wire [15:0] v_mono_data;
    wire [31:0] v_pair_data;
    reg [3:0] v_restart;
    always @(posedge mclk or posedge video_reset)begin
      if(video_reset)v_restart<=15;
      else if(v_restart!=0)v_restart<=v_restart-1'b1;
      else if(v_done)v_restart<=15;
    end
    wire v_reader_reset=video_reset || v_restart!=0;
    wire [31:0] arb_lba;wire arb_req;
    wire setting_toggle,album_next,album_prev;
    key_action u_confirm(.clk(mclk),.rst(mrst),.key_n(key_mode_n),.short_press(confirm_short),.long_press(home_long));
    wire voice_valid;wire [3:0] voice_command;wire music_paused;
    wire remote_pixel_valid;wire [3:0] remote_pixel_command;
    wire remote_valid;wire [3:0] remote_command;
    wire control_valid=voice_valid || remote_valid;
    wire [3:0] control_command=voice_valid?voice_command:remote_command;
    remote_command_bridge u_remote_bridge(.pclk(pclk),.prst(vrst),.event_valid(remote_pixel_valid),.event_command(remote_pixel_command),
        .mclk(mclk),.mrst(mrst),.valid(remote_valid),.command(remote_command));
    voice_command_rx u_voice(.clk(mclk),.rst(mrst),.rx(voice_rx),.valid(voice_valid),.command(voice_command));
    shell_control #(.LIBRARY(1),.LIBRARY_SWITCH(1),.PHOTO_CLEAN(1),.VOICE(1),.REMOTE(1)) u_shell(.clk(mclk),.rst(mrst),.next_press(next_press),.prev_press(prev_press),
        .remote_pause(remote_valid && remote_command==4),.voice_valid(control_valid),.voice_command(control_command),.music_paused(music_paused),
        .library_press(library_press),.library_ready(library_ready),.media_busy(quiescing),
        .music_count(music_count),.video_count(video_count),.library_open(library_open),.library_cursor(library_cursor),
        .music_selected(music_selected),.video_selected(video_selected),.file_restart(file_restart),
        .confirm_short(confirm_short),.home_long(home_long || (remote_valid && remote_command==15)),.page(app_page),.home_selected(home_selected),
        .settings_selected(settings_selected),.ui_toggle(ui_changed),.album_next(album_next),
        .album_prev(album_prev),.album_mode(mode_press),.setting_command(setting_command),.setting_toggle(setting_toggle),.video_paused(video_paused));
    wire [19:0] cache_valid,cache_tags;wire [3:0] cache_slots_valid;wire [4:0] photo_count,scan_count;wire scan_only,scan_done;
    wire prefetch,promote;
    cache_album_control #(.MAX_IMAGES(20),.SCAN(1),.TAGGED(1)) u_control(.clk(mclk),.rst(photo_reset),.init_done(init_done),
        .cache_valid(cache_valid),.cache_tags(cache_tags),.cache_slots_valid(cache_slots_valid),.prefetch(prefetch),.promote(promote),.scan_only(scan_only),.scan_done(scan_done),.scan_count(scan_count),.photo_count(photo_count),
        .presentation_active(app_page==2'd1),
        .period_long(period_long),.next_press(album_next),.prev_press(album_prev),.mode_press(mode_press),
        .swapped(swapped),.displayed(displayed),.load_failed(load_failed),.fatal_error(failed),
        .selected(selected),.busy(busy),.started(started),.begin_load(begin_load),
        .loader_reset(loader_reset),.auto_mode(auto_mode),.all_failed(all_failed));
    wire sd_reset_shared,image_wait,wav_wait,wav_reset,wav_req,wav_valid,wav_end,wav_done,wav_failed;
    wire [31:0] wav_lba;
    wire [7:0] wav_error;
    wire image_req,image_valid,image_end;
    wire [31:0] image_lba;
    wire music_sample_valid,music_sample_ready;
    wire [31:0] music_sample;
    wire [12:0] fifo_wlevel,fifo_rlevel;
    wire fifo_valid,fifo_pop;
    wire [31:0] fifo_sample;
    wire music_playing,music_underrun;
    reg [3:0] wav_restart;
    always @(posedge mclk or posedge photo_reset)begin
        if(photo_reset)wav_restart<=15;
        else if(wav_restart!=0)wav_restart<=wav_restart-1'b1;
        else if(wav_done)wav_restart<=15;
    end
    assign wav_reset=photo_reset || wav_restart!=0 || song_restarting;
    sd_read_arbiter u_card_arbiter(.clk(mclk),.rst(photo_reset),.sd_ready(sd_ready),
        .image_reset(loader_reset),.image_req(image_req),.image_lba(image_lba),
        .audio_reset(wav_reset),.audio_req(wav_req),.audio_lba(wav_lba),.audio_urgent(fifo_wlevel<1536),
        .image_wait(image_wait),.audio_wait(wav_wait),.image_valid(image_valid),.image_end(image_end),
        .audio_valid(wav_valid),.audio_end(wav_end),.sd_valid(sec_valid),.sd_end(sec_end),
        .sd_req(arb_req),.sd_lba(arb_lba),.sd_reset(sd_reset_shared));
    wire media_req,media_valid,media_done,media_failed;
    wire [31:0] media_lba,media_data;wire [7:0] media_error;
    assign wav_req=!video_owner && media_req;assign wav_lba=media_lba;
    assign v_req=video_owner && media_req;assign v_lba=media_lba;
    assign music_sample_valid=!video_owner && media_valid;assign music_sample=media_data;
    assign v_stream_valid=video_owner && media_valid;assign v_stream_data=media_data;
    assign wav_done=!video_owner && media_done;assign v_done=video_owner && media_done;
    assign wav_failed=!video_owner && media_failed;assign v_failed=video_owner && media_failed;
    assign wav_error=media_error;assign v_error=media_error;
    wire [14:0] video_total_m;wire video_meta_valid_m;
    fat32_media_stream #(.SELECTABLE(1)) u_media_reader(.clk(mclk),.rst(video_owner?v_reader_reset:wav_reset),
      .selected_file(video_owner?video_selected:music_selected),.catalog_entry(catalog_entry),
      .catalog_index(catalog_index),.catalog_name(catalog_name),.catalog_count(catalog_count),.catalog_done(catalog_done),
      .enable(init_done),.sd_ready(sd_ready),.video_mode(video_owner),.io_wait(video_owner?1'b0:wav_wait),
      .sector_req(media_req),.sector_lba(media_lba),
      .byte_valid(video_owner?(sec_valid && !switching):wav_valid),.byte_data(sec_byte),
      .sector_end(video_owner?(sec_end && !switching):wav_end),
      .sample_valid(media_valid),.sample_ready(video_owner?v_stream_ready:music_sample_ready),.sample_data(media_data),
      .video_total_frames(video_total_m),.video_meta_valid(video_meta_valid_m),
      .done(media_done),.failed(media_failed),.error_code(media_error),.debug_state());
    wire shared_wready,music_fifo_pop,video_fifo_pop;
    assign music_sample_ready=shared_wready && !video_owner && !switching && !song_restarting;
    assign v_pair_ready=shared_wready && video_owner && !switching;
    assign fifo_pop=owner_pixel?video_fifo_pop:music_fifo_pop;
    audio_fifo u_audio_fifo(.wclk(mclk),.rclk(pclk),.rst(~clocks_ready),.wflush(switching || song_restarting),.rflush(switch_pixel || song_restart_pixel),
        .wvalid(!switching && !song_restarting && (video_owner?v_pair_valid:music_sample_valid)),
        .wdata(video_owner?v_pair_data:music_sample),.wready(shared_wready),
        .rpop(fifo_pop),.rvalid(fifo_valid),.rdata(fifo_sample),.wlevel(fifo_wlevel),.rlevel(fifo_rlevel));
    sd_read_bridge u_sd(
        .sd_clk(unused100),
        .clk(mclk),.rst(mrst || switching || (!video_owner && sd_reset_shared)),.SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),.SD_MOSI(sd_mosi),.SD_MISO(sd_miso),
        .read_stream(1'b1),.sd_init_done(sd_ready),.sd_sec_read(sec_req),.sd_sec_read_addr(sec_lba),
        .sd_sec_read_data(sec_byte),.sd_sec_read_data_valid(sec_valid),.sd_sec_read_end(sec_end),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
        .sd_sec_write_data_req(),.sd_sec_write_end());
    fat32_bmp_loader #(.INDEX_BITS(5),.CATALOG(1)) u_loader(.clk(mclk),.rst(loader_reset),.image_index(selected),.scan_only(scan_only),.scan_done(scan_done),.image_count(scan_count),.enable(init_done && started),.sd_ready(sd_ready),.io_wait(image_wait),
        .sector_req(image_req),.sector_lba(image_lba),.byte_valid(image_valid),.byte_data(sec_byte),.sector_end(image_end),
        .group_valid(group_valid),.group_ready(group_ready),.group_addr(group_addr),.group_data(group_data),
        .done(load_done),.failed(load_failed),.error_code(load_error),.debug_state());
    reg [2:0] memory_req_pipe;reg [8:0] memory_row_meta,memory_row_sync;
    always @(posedge mclk or posedge mrst)begin
      if(mrst)begin memory_req_pipe<=0;memory_row_meta<=0;memory_row_sync<=0;end
      else begin memory_req_pipe<={memory_req_pipe[1:0],req};memory_row_meta<=req_row;memory_row_sync<=memory_row_meta;end
    end
    reg held_req;reg [8:0] held_row;
    always @(posedge mclk or posedge mrst)begin
      if(mrst)begin held_req<=0;held_row<=0;end
      else if(!quiescing)begin held_req<=memory_req_pipe[2];held_row<=memory_row_sync;end
    end
    wire memory_req=quiescing?held_req:memory_req_pipe[2];
    wire [8:0] memory_row=quiescing?held_row:memory_row_sync;
    frame_store_cached #(.MAX_IMAGES(20)) u_store(.clk(mclk),.rst(photo_reset),.init_done(init_done),.refresh_busy(refresh_busy),
        .group_valid(group_valid && !quiescing),.group_ready(group_ready),.group_addr(group_addr),.group_data(group_data),
        .load_done(load_done),.load_failed(load_failed && !loader_reset),
        .cache_valid(cache_valid),.cache_tags(cache_tags),.cache_slots_valid(cache_slots_valid),.prefetch(prefetch),.promote(promote),
        .photo_count(photo_count),.swap_allowed(swap_allowed),.frame_pending(frame_pending),.begin_load(begin_load && !quiescing),.image_index(selected),.swapped(swapped),.displayed(displayed),
        .wr_en(p_wr_en),.wr_addr(p_wr_addr),.wr_data(p_wr_data),.rd_en(p_rd_en),.rd_addr(p_rd_addr),
        .rd_valid(rd_valid),.rd_data(rd_data),.line_req_toggle(memory_req),.line_req_row(memory_row),.line_ack_toggle(p_ack),
        .line_we(p_we),.line_waddr(p_line_waddr),.line_wdata(p_line_wdata),
        .tag_even(p_tag_even),.tag_odd(p_tag_odd),.valid_even(p_valid_even),.valid_odd(p_valid_odd),
        .committed(p_verified),.ready(p_ready),.failed(p_failed));
    wire [31:0] shared_line_data=video_owner?v_line_wdata:{8'd0,p_line_wdata};
    wire [2:0] video_fraction={vx[1]^vx[0],vx[0],1'b0};
    line_buffer #(.SMOOTH_VIDEO(1)) u_line(.wclk(mclk),.we(we),.waddr(line_waddr),.wdata(shared_line_data),.wvideo(video_owner),
        .rclk(pclk),.raddr(line_raddr),.rvideo(owner_pixel),.q(line_q),.rfrac(video_fraction));
    frame_video u_video(.pclk(pclk),.rst(vrst),.video_mode(owner_pixel),.view_reset(quiet_pixel),.mem_ready(ready),.mem_failed(failed),
        .mem_verified(verified),.mem_init(init_done),.mem_ack(ack),
        .tag_even(tag_even),.tag_odd(tag_odd),.valid_even(valid_even),.valid_odd(valid_odd),
        .req_toggle(req),.req_row(req_row),.line_raddr(line_raddr),.line_q(line_q),
        .hs(hs),.vs(vs),.de(de),.rgb(rgb_raw),.underrun(underrun),.pixel_x(vx),.pixel_y(vy));
    wire [1:0] brightness;
    wire [2:0] visible_page;wire [1:0] visible_home,visible_settings;
    wire clean_photo;
    wire sound_enable,switch_sound_enable,bhs,bvs,bde;
    wire [2:0] volume;wire [1:0] transition_mode,active_transition;
    assign sound_enable=switch_sound_enable && volume!=0;
    wire [9:0] bx,by;
    wire [9:0] album_overlay_y=(clean_photo && visible_page==3'd1)?10'd1023:by;
    // Command data remains stable for >4 ms between UART words. A synchronized
    // toggle delivers one event to the pixel domain after two data registers.
    reg voice_toggle;reg [3:0] voice_latched;
    always @(posedge mclk or posedge mrst)begin
      if(mrst)begin voice_toggle<=0;voice_latched<=0;end
      else if(control_valid)begin voice_latched<=control_command;voice_toggle<=~voice_toggle;end
    end
    reg [2:0] voice_pipe;reg voice_seen;reg [3:0] voice_meta,voice_pixel;
    reg music_pause_meta,music_pause_pixel;
    always @(posedge pclk or posedge vrst)begin
      if(vrst)begin voice_pipe<=0;voice_seen<=0;voice_meta<=0;voice_pixel<=0;music_pause_meta<=0;music_pause_pixel<=0;end
      else begin
        voice_pipe<={voice_pipe[1:0],voice_toggle};voice_seen<=voice_pipe[2];
        voice_meta<=voice_latched;voice_pixel<=voice_meta;
        music_pause_meta<=music_paused;music_pause_pixel<=music_pause_meta;
      end
    end
    wire voice_pixel_valid=voice_pipe[2]!=voice_seen;
    media_controls #(.PHOTO_CLEAN(1),.VOICE(1)) u_controls(.clk(pclk),.rst(vrst),.switches({1'b0,switches[2:0]}),.vs(vs),.video_mode(owner_pixel),
        .voice_valid(voice_pixel_valid),.voice_command(voice_pixel),
        .setting_toggle(setting_toggle),.setting_command(setting_command),
        .brightness(brightness),.sound_enable(switch_sound_enable),.period_long(period_long),.volume(volume),.transition_mode(transition_mode),.clean_photo(clean_photo));
    wire [4:0] fade_level;
    wire fhs,fvs,fde;
    wire [9:0] fx,fy;
    fade_control #(.AUTO_CYCLE(1)) u_fade_control(.clk(pclk),.rst(photo_pixel_reset),.vs(vs),.frame_pending(pending_photo_m),
        .mem_ready(ready),.level(fade_level),.swap_allowed(swap_allowed),.requested_mode(transition_mode),.active_mode(active_transition));
    fade_pipe u_fade(.clk(pclk),.rst(vrst),.mode(active_transition),.level(owner_pixel?5'd16:fade_level),
        .rgb_in(rgb_raw),.hs_in(hs),.vs_in(vs),.de_in(de),.x_in(vx),.y_in(vy),
        .rgb_out(rgb_faded),.hs_out(fhs),.vs_out(fvs),.de_out(fde),.x_out(fx),.y_out(fy));
    brightness_pipe u_brightness(.clk(pclk),.rst(vrst),.level(brightness),
        .rgb_in(rgb_faded),.hs_in(fhs),.vs_in(fvs),.de_in(fde),.x_in(fx),.y_in(fy),
        .rgb_out(rgb_bright),.hs_out(bhs),.vs_out(bvs),.de_out(bde),.x_out(bx),.y_out(by));
    wire status_failed;
    wire [7:0] status_code;
    music_error_status u_music_status(.mclk(mclk),.pclk(pclk),.mrst(photo_reset),.vrst(photo_pixel_reset),
        .mem_failed(failed),.image_failed(load_failed && !prefetch && !loader_reset),.all_failed(all_failed),.wav_failed(wav_failed),
        .image_code(load_error),.wav_code(wav_error),.underrun(music_underrun),.failed(status_failed),.code(status_code));
    player_ui #(.VOICE(1),.MAX_IMAGES(20)) u_ui(.paused(music_pause_pixel),.clk(pclk),.rst(vrst),.image_index(displayed),.image_count(photo_count),.busy(busy),.auto_mode(auto_mode),
        .brightness(brightness),.volume(volume),.sound_enable(sound_enable),.period_long(period_long),
        .playing(music_playing),.failed(status_failed),.error_code(status_code),
        .x(bx),.y(album_overlay_y),.rgb_in(rgb_bright),.rgb_out(rgb_params));
    wire audio_valid,acr_valid,m_audio_valid,m_acr_valid,v_audio_valid,v_acr_valid,v_playing,v_audio_under;
    wire [23:0] pcm_left,pcm_right,m_pcm_left,m_pcm_right,v_pcm_left,v_pcm_right;
    assign audio_valid=owner_pixel?v_audio_valid:m_audio_valid;
    assign acr_valid=owner_pixel?v_acr_valid:m_acr_valid;
    assign pcm_left=quiet_pixel?24'd0:(owner_pixel?v_pcm_left:m_pcm_left);
    assign pcm_right=quiet_pixel?24'd0:(owner_pixel?v_pcm_right:m_pcm_right);
    pcm_player #(.PREFILL(768),.PAUSE(1)) u_player(.clk(pclk),.rst(photo_pixel_reset || song_restart_pixel),.sound_enable(sound_enable),.paused(music_pause_pixel),
        .fifo_valid(fifo_valid),.fifo_data(fifo_sample),.fifo_level(fifo_rlevel),.fifo_pop(music_fifo_pop),
        .audio_valid(m_audio_valid),.left_data(m_pcm_left),.right_data(m_pcm_right),.acr_valid(m_acr_valid),
        .playing(music_playing),.underrun(music_underrun),.volume(volume));
    wire [23:0] rgb_wave;
    audio_wave_overlay u_wave(.clk(pclk),.rst(photo_pixel_reset),.vs(bvs),.audio_valid(audio_valid),.pcm(pcm_left),
        .x(bx),.y(album_overlay_y),.rgb_in(rgb_params),.rgb_out(rgb_wave));
    // HC-05 on J1 pins 3/4, 25 MHz / 651 = 38402.5 baud, 8N1.
    // Reuses the former caption UART; the independent D14 voice UART is unchanged.
    wire serial_valid,serial_error,serial_send,serial_ready;
    wire [7:0] serial_byte,serial_reply;
    uart_rx_byte #(.CLKS_PER_BIT(651)) u_uart_rx(.clk(pclk),.rst(vrst),.rx(uart_rx),
        .valid(serial_valid),.data(serial_byte),.error(serial_error));
    uart_tx_byte #(.CLKS_PER_BIT(651)) u_uart_tx(.clk(pclk),.rst(vrst),.valid(serial_send),
        .data(serial_reply),.ready(serial_ready),.tx(uart_tx));
    wire [23:0] rgb_subtitle;
    // Keep embedded movie captions unobscured; custom marquee remains on other pages.
    subtitle_overlay #(.REMOTE(1)) u_subtitle(.clk(pclk),.rst(vrst),.vs(bvs),
        .rx_valid(serial_valid),.rx_data(serial_byte),.rx_error(serial_error),
        .tx_valid(serial_send),.tx_data(serial_reply),.tx_ready(serial_ready),
        .remote_valid(remote_pixel_valid),.remote_command(remote_pixel_command),
        .x(bx),.y(owner_pixel?10'd0:album_overlay_y),.rgb_in(owner_pixel?video_hud:rgb_wave),.rgb_out(rgb_subtitle));
    ui_state_cdc u_ui_state(.clk(pclk),.rst(vrst),.vs(bvs),.source_toggle(ui_changed),
        .source_state({app_page,home_selected,settings_selected}),
        .page(visible_page),.home_selected(visible_home),.settings_selected(visible_settings));
    reg photo_ready_meta,photo_ready_pixel;
    always @(posedge pclk or posedge vrst)begin
        if(vrst)begin photo_ready_meta<=0;photo_ready_pixel<=0;end
        else begin photo_ready_meta<=photo_good_m;photo_ready_pixel<=photo_ready_meta;end
    end
    wire [31:0] home_meter;
    home_audio_meter u_home_meter(.clk(pclk),.rst(vrst),.vs(bvs),.audio_valid(audio_valid),
        .pcm(pcm_left),.sound_enable(sound_enable),.playing(music_playing),.levels(home_meter));
    wire [23:0] game_rgb,shell_rgb;
    shell_overlay #(.LIBRARY(1),.MAX_IMAGES(20),.PHOTO_CLEAN(1)) u_shell_ui(.clk(pclk),.rst(vrst),.page(visible_page==4?2'd1:visible_page[1:0]),
        .home_selected(visible_home),.settings_selected(visible_settings),
        .catalog_clk(mclk),.catalog_entry(catalog_entry),.catalog_type(video_owner),.catalog_index(catalog_index),.catalog_name(catalog_name),
        .library_open(library_open),.library_type(app_page==4),.library_ready(library_ready),
        .library_cursor(library_cursor),.library_count(app_page==4?video_count:music_count),.vs(bvs),
        .brightness(brightness),.sound_enable(sound_enable),.period_long(period_long),.playing(music_playing),
        .photo_ready(photo_ready_pixel),.image_count(photo_count),.image_index(displayed),.meter_levels(home_meter),.volume(volume),
        .x(bx),.y(by),.rgb_in(rgb_subtitle),.rgb_out(shell_rgb),.clean_photo(clean_photo));
    reg confirm_toggle;
    always @(posedge mclk or posedge mrst)begin
        if(mrst)confirm_toggle<=0;else if(confirm_short && app_page==2'd2)confirm_toggle<=~confirm_toggle;
    end
    wire left_held,right_held,left_click,right_click,game_confirm;
    arcade_input u_game_input(.clk(pclk),.rst(vrst),.left_n(key_next_n),.right_n(key_prev_n),
        .confirm_toggle(confirm_toggle),.left_held(left_held),.right_held(right_held),
        .left_click(left_click),.right_click(right_click),.confirm(game_confirm));
    wire game_view,game_selected;
    wire [2:0] game_state;
    wire [1:0] game_level,game_lives;
    wire [15:0] game_score;
    wire [31:0] game_bricks;
    wire [9:0] paddle_x,ball_x,trail_x0,trail_x1,trail_x2,hit_x;
    wire [8:0] ball_y,trail_y0,trail_y1,trail_y2,hit_y;
    wire [3:0] hit_timer;
    breakout_core #(.RUNNER(1)) u_game(.clk(pclk),.rst(vrst),.vs(bvs),.active(visible_page==2'd2),
        .left_held(left_held),.right_held(right_held),.left_click(left_click),.right_click(right_click),.confirm(game_confirm),
        .view_game(game_view),.selected(game_selected),.state(game_state),.level(game_level),.lives(game_lives),
        .score(game_score),.bricks(game_bricks),.paddle_x(paddle_x),.ball_x(ball_x),.ball_y(ball_y),
        .trail_x0(trail_x0),.trail_x1(trail_x1),.trail_x2(trail_x2),.trail_y0(trail_y0),.trail_y1(trail_y1),.trail_y2(trail_y2),
        .hit_x(hit_x),.hit_y(hit_y),.hit_timer(hit_timer));
    wire [2:0] runner_state;wire [1:0] runner_level;wire [15:0] runner_score,runner_best;
    wire [8:0] runner_y;wire [9:0] runner_ob0,runner_ob1,runner_scroll;wire [3:0] runner_glow;wire [4:0] runner_feedback;
    wire runner_sliding,runner_head0,runner_head1;
    wire runner_view=game_view && game_selected;
    runner_core #(.DUCK(1)) u_runner(.clk(pclk),.rst(vrst),.vs(bvs),.active(visible_page==2'd2 && runner_view),
      .jump(left_click),.slide(right_held),.sliding(runner_sliding),.overhead0(runner_head0),.overhead1(runner_head1),.confirm(game_confirm),.energy(home_meter[3:0]),
      .state(runner_state),.level(runner_level),.score(runner_score),.best(runner_best),.runner_y(runner_y),
      .obstacle0(runner_ob0),.obstacle1(runner_ob1),.scroll(runner_scroll),.glow(runner_glow),.feedback(runner_feedback));
    arcade_renderer #(.RUNNER_DUCK(1),.POLISH(1)) u_game_ui(.clk(pclk),.rst(vrst),.x(bx),.y(by),.view_game(game_view),.selected(game_selected),
        .state(runner_view?runner_state:game_state),.level(runner_view?runner_level:game_level),.lives(game_lives),.score(runner_view?runner_score:game_score),.bricks(game_bricks),
        .paddle_x(runner_view?runner_ob0:paddle_x),.ball_x(runner_view?runner_ob1:ball_x),.ball_y(runner_view?runner_y:ball_y),.trail_x0(runner_view?runner_scroll:trail_x0),.trail_x1(runner_view?{2'b00,runner_best[15:8]}:trail_x1),.trail_x2(runner_view?{2'b00,runner_best[7:0]}:trail_x2),
        .trail_y0(runner_view?{4'd0,runner_feedback}:trail_y0),.trail_y1(trail_y1),.trail_y2(trail_y2),.hit_x(hit_x),.hit_y(hit_y),.hit_timer(runner_view?runner_glow:hit_timer),.rgb(game_rgb),.runner_sliding(runner_sliding),.runner_overhead0(runner_head0),.runner_overhead1(runner_head1));
    reg [3:0] game_visible;reg [23:0] shell_rgb_delayed;
    always @(posedge pclk or posedge vrst)begin
        if(vrst)begin game_visible<=0;shell_rgb_delayed<=0;end
        else begin game_visible<={game_visible[2:0],visible_page==2'd2};shell_rgb_delayed<=shell_rgb;end
    end
    assign rgb=game_visible[3]?game_rgb:shell_rgb_delayed;

    assign sec_req=!switching && (video_owner?v_req:arb_req);
    assign sec_lba=video_owner?v_lba:arb_lba;
    assign wr_en=!switching && (video_owner?v_wr_en:p_wr_en);
    assign rd_en=!switching && (video_owner?v_rd_en:p_rd_en);
    assign wr_addr=video_owner?v_wr_addr:p_wr_addr;
    assign wr_data=video_owner?v_wr_data:p_wr_data;
    assign rd_addr=video_owner?v_rd_addr:p_rd_addr;
    assign we=!switching && (video_owner?v_we:p_we);
    assign line_waddr=video_owner?v_line_waddr:p_line_waddr;
    always @(posedge mclk or posedge mrst)begin
      if(mrst)begin ack_m<=0;ready_m<=0;failed_m<=0;verified_m<=0;ve_m<=0;vo_m<=0;tag_even_m<=0;tag_odd_m<=0;photo_good_m<=0;pending_photo_m<=0;end
      else begin
       ack_m<=video_owner?v_ack:p_ack;
       ready_m<=!quiescing && (video_owner?v_ready:p_ready);
       failed_m<=!quiescing && (video_owner?v_failed:p_failed);
       verified_m<=video_owner?v_ready:p_verified;
       ve_m<=!quiescing && (video_owner?v_valid_even:p_valid_even);
       vo_m<=!quiescing && (video_owner?v_valid_odd:p_valid_odd);
       tag_even_m<=video_owner?v_tag_even:p_tag_even;tag_odd_m<=video_owner?v_tag_odd:p_tag_odd;
       photo_good_m<=p_ready && !p_failed && !photo_reset;pending_photo_m<=frame_pending;
      end
    end
    assign ack=ack_m;assign ready=ready_m;assign failed=failed_m;assign verified=verified_m;
    assign tag_even=tag_even_m;assign tag_odd=tag_odd_m;assign valid_even=ve_m;assign valid_odd=vo_m;
    av_unpacker u_av_unpack(.clk(mclk),.rst(video_reset),.valid(v_stream_valid),.data(v_stream_data),.ready(v_stream_ready),
      .video_valid(v_video_valid),.video_data(v_video_data),.video_ready(v_video_ready),
      .audio_valid(v_mono_valid),.audio_data(v_mono_data),.audio_ready(v_mono_ready));
    mono_pair u_pair(.clk(mclk),.rst(video_reset),.valid(v_mono_valid),.data(v_mono_data),.ready(v_mono_ready),
      .out_valid(v_pair_valid),.out_data(v_pair_data),.out_ready(v_pair_ready));
    video_store u_video_store(.clk(mclk),.rst(video_reset),.init_done(init_done),.refresh_busy(refresh_busy),
      .paused(video_paused),.source_toggle(v_frame_toggle),.sample_valid(v_video_valid && !quiescing),.sample_data(v_video_data),.sample_ready(v_video_ready),
      .wr_en(v_wr_en),.wr_addr(v_wr_addr),.wr_data(v_wr_data),.rd_en(v_rd_en),.rd_addr(v_rd_addr),.rd_valid(rd_valid),.rd_data(rd_data),
      .line_req_toggle(memory_req),.line_req_row(memory_row),.line_ack_toggle(v_ack),.line_we(v_we),.line_waddr(v_line_waddr),.line_wdata(v_line_wdata),
      .tag_even(v_tag_even),.tag_odd(v_tag_odd),.valid_even(v_valid_even),.valid_odd(v_valid_odd),.ready(v_ready),
      .displayed_frames(v_frames),.late_frames(v_late),.frame_pending(v_pending));
    reg v_ready_meta,v_ready_pixel,v_pending_meta,v_pending_pixel,v_fail_meta,v_fail_pixel,v_enable;
    always @(posedge pclk or posedge video_pixel_reset)begin
      if(video_pixel_reset)begin v_ready_meta<=0;v_ready_pixel<=0;v_pending_meta<=0;v_pending_pixel<=0;v_fail_meta<=0;v_fail_pixel<=0;v_enable<=0;end
      else begin
        v_ready_meta<=v_ready;v_ready_pixel<=v_ready_meta;v_pending_meta<=v_pending;v_pending_pixel<=v_pending_meta;
        v_fail_meta<=v_failed;v_fail_pixel<=v_fail_meta;
        if(vx==0 && vy==0 && v_ready_pixel)v_enable<=1;
      end
    end
    video_pcm_player u_video_pcm(.clk(pclk),.rst(video_pixel_reset),.enable(v_enable && !v_fail_pixel),.paused(pause_pixel),
      .fifo_valid(fifo_valid),.fifo_data(fifo_sample),.fifo_level(fifo_rlevel),.fifo_pop(video_fifo_pop),
      .audio_valid(v_audio_valid),.acr_valid(v_acr_valid),.left_data(v_pcm_left),.right_data(v_pcm_right),
      .frame_toggle(v_frame_toggle),.underrun(v_audio_under),.playing(v_playing),.volume(sound_enable?volume:3'd0),.frame_available(v_pending_pixel));
    // Stable-bus CDC: metadata remains valid for the whole file; delayed valid follows two data registers.
    reg [14:0] total_meta,total_sync,total_hold;reg [2:0] total_valid;
    always @(posedge pclk or posedge video_pixel_reset)begin
      if(video_pixel_reset)begin total_meta<=0;total_sync<=0;total_hold<=0;total_valid<=0;end
      else begin total_meta<=video_total_m;total_sync<=total_meta;
        total_valid<={total_valid[1:0],video_meta_valid_m};
        if(total_valid[2])total_hold<=total_sync;
      end
    end
    wire [9:0] video_progress_pixels;wire [15:0] video_elapsed_bcd,video_total_bcd;
    video_progress u_progress(.clk(pclk),.rst(video_pixel_reset),.total_frames(total_hold),
      .word_consumed(video_fifo_pop && fifo_valid),.pixels(video_progress_pixels),.elapsed_bcd(video_elapsed_bcd),.total_bcd(video_total_bcd));
    video_hud u_video_hud(.x(bx),.y(by),.rgb_in(rgb_bright),.paused(pause_pixel),.ready(v_ready_pixel),.failed(v_fail_pixel),
      .volume(sound_enable?volume:3'd0),.progress(video_progress_pixels),.elapsed_bcd(video_elapsed_bcd),.total_bcd(video_total_bcd),.rgb_out(video_hud));

    wire axis_user,axis_valid,axis_last,axis_ready,video_locked;
    wire [23:0] axis_data;
    reg [2:0] shell_vs,shell_de;
    always @(posedge pclk or posedge vrst)begin
        if(vrst)begin shell_vs<=3;shell_de<=0;end
        else begin shell_vs<={shell_vs[1:0],bvs};shell_de<={shell_de[1:0],bde};end
    end
    rgb_to_axis u_axis(.clk(pclk),.rst(vrst),.vs(shell_vs[2]),.de(shell_de[2]),.rgb(rgb),
        .user(axis_user),.valid(axis_valid),.last(axis_last),.data(axis_data));
    reg [17:0] edid_count;
    wire edid_trig=(edid_count==18'd100000);
    always @(posedge pclk or posedge vrst) begin
        if(vrst) edid_count<=0;
        else if(edid_count<18'd100001) edid_count<=edid_count+1'b1;
    end
    wire [9:0] ch0,ch1,ch2,chclk;
    hdmi_1_4b_transmitter_core_wrapper #(.DEVICE("EG"),
        .HTOTAL(800),.HSA(96),.HFP(16),.HBP(48),.HACTIVE(640),
        .VTOTAL(525),.VSA(2),.VFP(10),.VBP(33),.VACTIVE(480),
        .VIDEO_VIC(1),.VIDEO_TPG("Disable"),.VIDEO_FORMAT("RGB"),
        .AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(250)) u_hdmi(
        .I_pixel_clk(pclk),.I_rst(vrst),.I_edid_read_trig(edid_trig),
        .O_edid_read_valid(),.O_edid_read_data(),
        .I_axis_s_user(axis_user),.I_axis_s_valid(axis_valid),.I_axis_s_last(axis_last),
        .I_axis_s_data(axis_data),.O_axis_s_ready(axis_ready),
        .I_audio_valid(audio_valid),.I_audio_left_data(pcm_left),.I_audio_right_data(pcm_right),
        .I_acr_valid(acr_valid),.I_acr_cts(20'd25000),.I_acr_n(20'd6144),
        .O_video_locked(video_locked),.O_ddc_scl(HDMI_DDC_SCL),.IO_ddc_sda(HDMI_DDC_SDA),
        .O_ch0_tmds_data(ch0),.O_ch1_tmds_data(ch1),.O_ch2_tmds_data(ch2),.O_clk_tmds_data(chclk));
    hdmi_phy_wrapper #(.DEVICE("EG")) u_phy(.I_pixel_clk(pclk),.I_serial_clk(serial_clk),.I_rst(vrst),
        .I_tmds_channel_0(ch0),.I_tmds_channel_1(ch1),.I_tmds_channel_2(ch2),.I_tmds_channel_clk(chclk),
        .O_tmds_ch0_p(HDMI_D0_P),.O_tmds_ch1_p(HDMI_D1_P),.O_tmds_ch2_p(HDMI_D2_P),.O_tmds_clk_p(HDMI_CLK_P));
    assign HDMI_CLK_P1=HDMI_CLK_P;
    assign HDMI_D2_P1=HDMI_D2_P;
    assign HDMI_D1_P1=HDMI_D1_P;
    assign HDMI_D0_P1=HDMI_D0_P;
endmodule
