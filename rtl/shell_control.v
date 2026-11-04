// Memory-domain navigation. Only album mode receives media button events.
module shell_control #(parameter LIBRARY=0,TRANSITIONS=0,LIBRARY_SWITCH=0,PHOTO_CLEAN=0,VOICE=0,REMOTE=0)(input wire clk,rst,next_press,prev_press,confirm_short,home_long,
 output reg [2:0] page,output reg [1:0] home_selected,settings_selected,output reg ui_toggle,
 output reg album_next,album_prev,album_mode,
 output reg [1:0] setting_command,output reg setting_toggle,output reg video_paused,
 input wire library_press,library_ready,media_busy,input wire [3:0] music_count,video_count,
 output reg library_open,output reg [2:0] library_cursor,music_selected,video_selected,
 output reg file_restart,input wire remote_pause,input wire voice_valid,input wire [3:0] voice_command,output reg music_paused);
 reg library_armed;
 wire switch_open=LIBRARY_SWITCH && library_press && library_armed && !library_open;
 wire switch_close=LIBRARY_SWITCH && !library_press && library_open;
 wire library_event=LIBRARY_SWITCH?switch_open:library_press;
 wire [3:0] list_count=page==4?video_count:music_count;
 localparam HOME=0,ALBUM=1,GAMES=2,SETTINGS=3,VIDEO=4;
 always @(posedge clk or posedge rst)begin
  if(rst)begin music_paused<=0;library_armed<=1;page<=HOME;home_selected<=0;settings_selected<=0;ui_toggle<=0;
   album_next<=0;album_prev<=0;album_mode<=0;setting_command<=0;setting_toggle<=0;video_paused<=0;library_open<=0;library_cursor<=0;music_selected<=0;video_selected<=0;file_restart<=0;end
  else begin
   if(!library_press)library_armed<=1;
   else if(home_long || (switch_open && (page==ALBUM || page==VIDEO)))library_armed<=0;
   album_next<=0;album_prev<=0;album_mode<=0;file_restart<=0;
   if(home_long)begin library_open<=0;if(page!=HOME)begin page<=HOME;ui_toggle<=~ui_toggle;end end
   else if(REMOTE && remote_pause)begin
    if(page==VIDEO)video_paused<=~video_paused;else if(page==ALBUM)music_paused<=~music_paused;
   end
   else if(VOICE && voice_valid && voice_command>=1 && voice_command<=10)begin
    case(voice_command)
     1,8:begin
      page<=ALBUM;library_open<=0;library_armed<=0;ui_toggle<=~ui_toggle;
      if(voice_command==1)music_paused<=0;
     end
     5:begin page<=VIDEO;library_open<=0;library_armed<=0;video_paused<=0;ui_toggle<=~ui_toggle;end
     4:begin if(page==VIDEO)video_paused<=1;else if(page==ALBUM)music_paused<=1;end
     2,3:if(page==ALBUM && library_ready && !media_busy && music_count!=0)begin
      music_selected<=voice_command==2 ?
       ({1'b0,music_selected}+4'd1>=music_count?3'd0:music_selected+1'b1) :
       (music_selected==0?music_count[2:0]-1'b1:music_selected-1'b1);
      file_restart<=1;music_paused<=0;library_open<=0;library_armed<=0;
     end
     6,7:if(page==VIDEO && library_ready && !media_busy && video_count!=0)begin
      video_selected<=voice_command==6 ?
       ({1'b0,video_selected}+4'd1>=video_count?3'd0:video_selected+1'b1) :
       (video_selected==0?video_count[2:0]-1'b1:video_selected-1'b1);
      file_restart<=1;video_paused<=0;library_open<=0;library_armed<=0;
     end
     9,10:if(page==ALBUM && !library_open && !media_busy)begin
      album_next<=voice_command==9;album_prev<=voice_command==10;
     end
     default:begin end
    endcase
   end
   else if(LIBRARY && switch_close)library_open<=0;
   else if(LIBRARY && library_event && (page==ALBUM || page==VIDEO))begin
    library_open<=~library_open;library_cursor<=page==VIDEO?video_selected:music_selected;
   end else if(LIBRARY && library_open)begin
    if(library_ready && list_count!=0)begin
     if(next_press)library_cursor<=({1'b0,library_cursor}+4'd1>=list_count)?3'd0:library_cursor+1'b1;
     else if(prev_press)library_cursor<=library_cursor==0?list_count[2:0]-1'b1:library_cursor-1'b1;
     else if(confirm_short && !media_busy)begin
      library_open<=0;
      if(page==VIDEO)begin video_selected<=library_cursor;file_restart<=library_cursor!=video_selected;video_paused<=0;end
      else begin music_selected<=library_cursor;file_restart<=library_cursor!=music_selected;music_paused<=0;end
     end
    end
   end
   else case(page)
    HOME:begin
     if(next_press)begin case(home_selected)0:home_selected<=3;3:home_selected<=1;1:home_selected<=2;default:home_selected<=0;endcase ui_toggle<=~ui_toggle;end
     else if(prev_press)begin case(home_selected)0:home_selected<=2;2:home_selected<=1;1:home_selected<=3;default:home_selected<=0;endcase ui_toggle<=~ui_toggle;end
     else if(confirm_short)begin page<=home_selected==3?3'd4:{1'b0,home_selected}+3'd1;video_paused<=0;ui_toggle<=~ui_toggle;end
    end
    VIDEO:begin
     if(confirm_short)video_paused<=~video_paused;
     if(next_press || prev_press)begin setting_command<=next_press?2'd1:2'd3;setting_toggle<=~setting_toggle;end
    end
    ALBUM:begin
     if(next_press)album_next<=1;else if(prev_press)album_prev<=1;
     if(confirm_short)album_mode<=1;
    end
    GAMES:begin end // Arcade owns short confirm; long HOME still handled above.
    SETTINGS:begin
     if(next_press)begin settings_selected<=settings_selected+1'b1;ui_toggle<=~ui_toggle;end
     else if(prev_press)begin settings_selected<=settings_selected-1'b1;ui_toggle<=~ui_toggle;end
     else if(confirm_short)begin
      if(settings_selected==3 && !TRANSITIONS && !PHOTO_CLEAN)begin page<=HOME;ui_toggle<=~ui_toggle;end
      else begin setting_command<=settings_selected;setting_toggle<=~setting_toggle;end
     end
    end
   endcase
  end
 end
endmodule
