package cn.suki.remote;

import android.Manifest;
import android.app.*;
import android.bluetooth.*;
import android.content.*;
import android.content.ClipboardManager;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.*;
import android.provider.Settings;
import android.text.*;
import android.view.*;
import android.widget.*;
import java.util.*;

public class MainActivity extends Activity implements SppLink.Listener {
    private final int INK=0xff183342,MUTED=0xff798993,BLUE=0xff3567ee,PAPER=0xfff4f6f8;
    private SharedPreferences prefs;private CaptionLink link;private SppLink spp;private BleLink ble;private BluetoothAdapter adapter;
    private LinearLayout root,body,nav;private TextView badge,status,widthLabel,catalogStatus;private Button sendButton,connectButton;
    private final List<Button> remoteButtons=new ArrayList<>();
    private CaptionPreview preview;private CaptionRaster raster;private EditText editor;private Spinner deviceSpinner,modeSpinner,channelSpinner;
    private final List<BluetoothDevice> devices=new ArrayList<>();
    private String draft="多媒体娱乐屏",selectedMac="",detail="尚未连接蓝牙设备",connection="DISCONNECTED";
    private int speed=2,color=0xffb8ffd9,page=0,sequence=0,transportMode=0;private boolean visible=true,expectAck=false,valid=true;
    private final StringBuilder diagnostics=new StringBuilder("多媒体娱乐屏 0.1.8 / Android "+Build.VERSION.RELEASE+" / "+Build.MANUFACTURER+" "+Build.MODEL+"\n");
    private final Handler handler=new Handler(Looper.getMainLooper());private int permissionAction;

    @Override public void onCreate(Bundle state){super.onCreate(state);
        prefs=getSharedPreferences("suki",MODE_PRIVATE);
        if(!prefs.getBoolean("brand_migrated_016",false)){
            SharedPreferences.Editor migration=prefs.edit();
            for(String key:new String[]{"draft","saved"}){String old=prefs.getString(key,"");
                if(old.equals("suki的音乐世界"))migration.putString(key,"多媒体娱乐屏");
                else if(old.equals("欢迎体验 SUKI 多功能媒体游戏机"))migration.putString(key,"欢迎体验多媒体娱乐屏");}
            migration.putBoolean("brand_migrated_016",true).apply();
        }
        if(!prefs.getBoolean("brand_migrated_017",false)){
            SharedPreferences.Editor migration=prefs.edit();
            for(String key:new String[]{"draft","saved"}){String old=prefs.getString(key,"");
                if(old.contains("多媒体游戏屏"))migration.putString(key,old.replace("多媒体游戏屏","多媒体娱乐屏"));}
            migration.putBoolean("brand_migrated_017",true).apply();
        }
        draft=prefs.getString("draft",draft);speed=prefs.getInt("speed",2);
        color=prefs.getInt("color",color);visible=prefs.getBoolean("visible",true);expectAck=prefs.getBoolean("ack",false);selectedMac=prefs.getString("device","");transportMode=prefs.getInt("transport_mode",0);
        BluetoothManager manager=(BluetoothManager)getSystemService(BLUETOOTH_SERVICE);adapter=manager==null?null:manager.getAdapter();spp=new SppLink(listenerFor(false));ble=new BleLink(this,listenerFor(true),new BleLink.Observer(){public void trace(String s){if(link==ble)logDiagnostic(s);}public void channels(List<String> choices,int selected){if(link==ble)updateChannels(choices,selected);}});link=spp;
        root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setBackgroundColor(PAPER);
        root.setOnApplyWindowInsetsListener((v,insets)->{if(Build.VERSION.SDK_INT>=30){android.graphics.Insets bars=insets.getInsets(WindowInsets.Type.systemBars()|WindowInsets.Type.ime());v.setPadding(bars.left,bars.top,bars.right,bars.bottom);}else v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
        setContentView(root);root.requestApplyInsets();render();
    }
    private int dp(float v){return (int)(v*getResources().getDisplayMetrics().density+.5f);}
    private GradientDrawable bg(int fill,int radius){GradientDrawable d=new GradientDrawable();d.setColor(fill);d.setCornerRadius(dp(radius));return d;}
    private TextView text(String s,int size,int ink,boolean bold){TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(ink);t.setLineSpacing(dp(3),1);if(bold)t.setTypeface(Typeface.create("sans-serif-medium",Typeface.NORMAL));return t;}
    private LinearLayout column(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.VERTICAL);return v;}
    private LinearLayout row(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.HORIZONTAL);v.setGravity(Gravity.CENTER_VERTICAL);return v;}
    private void gap(LinearLayout v,int h){View g=new View(this);v.addView(g,new LinearLayout.LayoutParams(1,dp(h)));}
    private void paragraph(LinearLayout v,String s){TextView t=text(s,13,MUTED,false);v.addView(t);gap(v,14);}
    private LinearLayout card(LinearLayout host){LinearLayout c=column();c.setPadding(dp(18),dp(18),dp(18),dp(18));c.setBackground(bg(Color.WHITE,22));LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.bottomMargin=dp(15);host.addView(c,lp);return c;}
    private Button button(String title,boolean primary,Runnable action){Button b=new Button(this);b.setText(title);b.setTextSize(14);b.setAllCaps(false);b.setTextColor(primary?Color.WHITE:BLUE);b.setBackground(bg(primary?BLUE:0xffedf2ff,14));b.setBackgroundTintList(new ColorStateList(new int[][]{new int[]{-android.R.attr.state_enabled},new int[]{}},new int[]{0xffd5dce6,primary?BLUE:0xffedf2ff}));b.setElevation(dp(primary?2:0));b.setPadding(dp(14),dp(8),dp(14),dp(8));b.setMinHeight(dp(48));b.setOnClickListener(v->action.run());return b;}
    private void equal(LinearLayout r,View child){LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(0,-2,1);p.setMargins(dp(3),0,dp(3),0);r.addView(child,p);}
    private void notifyUser(String s){Toast.makeText(this,s,Toast.LENGTH_LONG).show();}
    private SppLink.Listener listenerFor(boolean lowEnergy){return new SppLink.Listener(){public void state(String state,String detail){if((lowEnergy&&link==ble)||(!lowEnergy&&link==spp))MainActivity.this.state(state,detail);}public void sent(String detail,boolean verified){if((lowEnergy&&link==ble)||(!lowEnergy&&link==spp))MainActivity.this.sent(detail,verified);}};}
    private boolean activeSession(){return !connection.equals("DISCONNECTED");}
    private void render(){remoteButtons.clear();root.removeAllViews();status=null;sendButton=null;connectButton=null;preview=null;editor=null;widthLabel=null;deviceSpinner=null;modeSpinner=null;catalogStatus=null;channelSpinner=null;
        LinearLayout header=row();header.setPadding(dp(22),dp(15),dp(22),dp(12));TextView title=text("多媒体娱乐屏",23,INK,true);header.addView(title,new LinearLayout.LayoutParams(0,-2,1));
        badge=text(connection.equals("CONNECTED")?"● 数据通道就绪":connection.equals("SELECT_CHANNEL")?"○ 待选通道":connection.equals("CONNECTING")?"○ 连接中":"○ 未连接",12,BLUE,false);badge.setPadding(dp(10),dp(10),dp(10),dp(10));badge.setOnClickListener(v->{page=2;render();});header.addView(badge);root.addView(header);
        ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);body=column();body.setPadding(dp(22),dp(6),dp(22),dp(18));scroll.addView(body);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        if(page==0)captionPage();else if(page==1)remotePage();else devicePage();
        nav=row();nav.setPadding(dp(12),dp(7),dp(12),dp(8));nav.setBackgroundColor(Color.WHITE);String[] labels={"字幕","遥控","设备"};for(int i=0;i<3;i++){final int n=i;Button b=button(labels[i],false,()->{page=n;render();});b.setTextColor(i==page?BLUE:MUTED);b.setBackgroundTintList(ColorStateList.valueOf(i==page?0xffedf2ff:Color.WHITE));equal(nav,b);}root.addView(nav);
        refreshButtons();
    }
    private void heading(String title,String subtitle){body.addView(text(title,27,INK,true));gap(body,5);paragraph(body,subtitle);}
    private void captionPage(){heading("让小屏，听你的。","留一句话，把此刻的心情放上屏幕。");
        preview=new CaptionPreview(this);LinearLayout.LayoutParams pp=new LinearLayout.LayoutParams(-1,dp(151));pp.bottomMargin=dp(18);body.addView(preview,pp);
        LinearLayout c=card(body);c.addView(text("写下你的字幕",16,INK,true));gap(c,12);
        editor=new EditText(this);editor.setText(draft);editor.setTextSize(16);editor.setTextColor(INK);editor.setGravity(Gravity.TOP);editor.setMinLines(3);editor.setMaxLines(6);editor.setPadding(dp(12),dp(10),dp(12),dp(10));editor.setBackground(bg(PAPER,12));editor.setHint("输入中文或英文…");editor.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE);editor.setFilters(new InputFilter[]{new InputFilter.LengthFilter(1000)});c.addView(editor,new LinearLayout.LayoutParams(-1,-2));
        widthLabel=text("",11,MUTED,false);c.addView(widthLabel);gap(c,10);
        editor.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int start,int count,int after){}public void onTextChanged(CharSequence s,int start,int before,int count){draft=s.toString();updatePreview();}public void afterTextChanged(Editable s){}});
        LinearLayout presets=row();equal(presets,button("音乐世界",false,()->editor.setText("多媒体娱乐屏")));equal(presets,button("欢迎语",false,()->editor.setText("欢迎体验多媒体娱乐屏")));c.addView(presets);gap(c,8);
        Switch show=new Switch(this);show.setText("在屏幕上显示字幕");show.setTextSize(14);show.setTextColor(INK);show.setChecked(visible);show.setOnCheckedChangeListener((v,b)->{visible=b;updatePreview();});c.addView(show);
        c=card(body);c.addView(text("滚动节奏",16,INK,true));gap(c,10);LinearLayout speeds=row();String[] names={"慢速","舒缓","轻快","快速"};for(int i=1;i<=4;i++){final int n=i;Button b=button(names[i-1],speed==i,()->{speed=n;persist();render();});b.setTextSize(12);b.setPadding(0,0,0,0);equal(speeds,b);}c.addView(speeds);gap(c,14);c.addView(text("字幕颜色",14,INK,false));gap(c,8);LinearLayout colors=row();int[] inks={0xffb8ffd9,0xfff3f6fa,0xff68ceff,0xffffd48a,0xfff3a2d3};String[] colorNames={"薄荷绿","柔白","天空蓝","暖金","樱花粉"};for(int i=0;i<inks.length;i++){final int ink=inks[i];Button b=button(color==ink?"✓":"●",false,()->{color=ink;persist();render();});b.setContentDescription(colorNames[i]);b.setTextColor(ink);b.setBackgroundTintList(ColorStateList.valueOf(INK));b.setPadding(0,0,0,0);equal(colors,b);}c.addView(colors);
        sendButton=button("发送到开发板",true,this::sendCaption);body.addView(sendButton,new LinearLayout.LayoutParams(-1,-2));gap(body,8);status=text(detail,12,MUTED,false);body.addView(status);gap(body,10);
        LinearLayout saved=row();equal(saved,button("保存常用",false,()->{prefs.edit().putString("saved",draft).apply();persist();notifyUser("字幕已保存在手机");}));equal(saved,button("读取常用",false,()->editor.setText(prefs.getString("saved","多媒体娱乐屏"))));body.addView(saved);
        gap(body,10);paragraph(body,"字幕显示于支持滚动字幕的页面；纯照片模式和视频页的隐藏规则仍由开发板决定。");
        updatePreview();
    }
    private void updatePreview(){try{raster=CaptionRaster.render(draft,color);valid=true;if(preview!=null)preview.update(raster,visible,speed);if(widthLabel!=null){widthLabel.setText("字模 "+raster.columns.length+" / 2048 像素 · 手机与发送字模一致");widthLabel.setTextColor(MUTED);}}catch(IllegalArgumentException e){valid=false;if(widthLabel!=null){widthLabel.setText(e.getMessage());widthLabel.setTextColor(0xffc53b42);}}refreshButtons();}
    private Button remoteButton(String title,int command){Button b=button(title,false,()->sendRemote(command,title));remoteButtons.add(b);return b;}
    private void remoteRow(LinearLayout host,String left,int a,String right,int b){LinearLayout r=row();equal(r,remoteButton(left,a));equal(r,remoteButton(right,b));host.addView(r);gap(host,8);}
    private void remotePage(){heading("你的掌上控制台","音乐、影像与照片，随手切换。");
        LinearLayout c=card(body);c.addView(text("打开媒体",17,INK,true));gap(c,12);
        remoteRow(c,"音乐相册",1,"视频播放",5);remoteRow(c,"照片相册",8,"返回主页",15);
        c=card(body);c.addView(text("播放控制",17,INK,true));gap(c,12);
        Button toggle=remoteButton("播放 / 暂停",4);c.addView(toggle,new LinearLayout.LayoutParams(-1,-2));gap(c,10);
        remoteRow(c,"上一首",3,"下一首",2);remoteRow(c,"上一视频",7,"下一视频",6);remoteRow(c,"上一张照片",10,"下一张照片",9);
        c=card(body);c.addView(text("声音与画面",17,INK,true));gap(c,12);
        remoteRow(c,"音量 −",12,"音量 ＋",11);remoteRow(c,"亮度 −",14,"亮度 ＋",13);
        status=text(detail,13,MUTED,false);body.addView(status);gap(body,12);
        paragraph(body,"上一首和切图在相册页使用，上一视频在视频页使用。媒体切换加载时请稍候；实体静音开关仍有效。需要配套媒体遥控固件，手机不会传输媒体文件。");
    }
    private void sendRemote(int command,String title){
        if(!link.isConnected()){page=2;render();notifyUser("请先连接蓝牙设备");return;}
        if(link.isBusy())return;
        int id=++sequence&255;detail="正在发送："+title;if(status!=null)status.setText(detail);
        logDiagnostic("媒体遥控 command="+command+" seq="+id);
        if(!link.send(CaptionProtocol.remotePacket(command,id),id,expectAck)){detail="当前不可发送，请稍候重试";if(status!=null)status.setText(detail);}
        refreshButtons();
    }
    private boolean permission(){return Build.VERSION.SDK_INT<31||checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED;}
    private boolean scanPermission(){return Build.VERSION.SDK_INT<31||checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED;}
    private void withPermission(int action){List<String> needed=new ArrayList<>();if(!permission())needed.add(Manifest.permission.BLUETOOTH_CONNECT);if(action==2&&!scanPermission())needed.add(Manifest.permission.BLUETOOTH_SCAN);if(!needed.isEmpty()){permissionAction=action;requestPermissions(needed.toArray(new String[0]),4);return;}if(action==1)loadDevices();else connectSelected();}
    @Override public void onRequestPermissionsResult(int code,String[] permissions,int[] results){super.onRequestPermissionsResult(code,permissions,results);if(code==4){if(permission()){if(permissionAction==1)loadDevices();else if(devices.isEmpty()){loadDevices();notifyUser("设备列表已更新，请选择HC-05后再连接");}else connectSelected();}else{detail="未允许附近设备权限，请在系统应用设置中开启后重试";notifyUser(detail);render();}}}
    private void devicePage(){heading("连接你的小屏","BLE + 经典 SPP · APP 0.1.8");LinearLayout c=card(body);c.addView(text("全部已配对设备",16,INK,true));gap(c,6);
        catalogStatus=text("尚未读取系统配对列表",12,MUTED,false);c.addView(catalogStatus);gap(c,6);
        deviceSpinner=new Spinner(this);deviceSpinner.setContentDescription("选择已配对的 HC-05");c.addView(deviceSpinner,new LinearLayout.LayoutParams(-1,dp(54)));
        c.addView(button("刷新已配对设备",false,()->withPermission(1)));gap(c,12);
        c.addView(text("连接方式",14,INK,true));modeSpinner=new Spinner(this);modeSpinner.setContentDescription("选择蓝牙协议");modeSpinner.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,new String[]{"自动（按系统类型）","BLE 低功耗连接","经典 SPP 兼容连接","经典 SPP 标准连接"}));modeSpinner.setSelection(transportMode);modeSpinner.setEnabled(!activeSession());modeSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){public void onItemSelected(AdapterView<?> p,View v,int pos,long id){transportMode=pos;prefs.edit().putInt("transport_mode",transportMode).apply();}public void onNothingSelected(AdapterView<?> p){}});c.addView(modeSpinner,new LinearLayout.LayoutParams(-1,dp(54)));
        paragraph(c,"系统标记BLE的模块自动使用GATT探测；也可手动选协议。名称HC-05不代表一定支持SPP。只连接自己的串口模块。");
        connectButton=button(activeSession()?"断开 / 取消连接":"连接所选设备",true,()->{if(activeSession())link.disconnect();else withPermission(2);});c.addView(connectButton,new LinearLayout.LayoutParams(-1,-2));gap(c,10);
        status=text(detail,12,MUTED,false);status.setTextIsSelectable(true);c.addView(status);gap(c,10);c.addView(button("复制连接诊断",false,()->{ClipboardManager clipboard=(ClipboardManager)getSystemService(CLIPBOARD_SERVICE);clipboard.setPrimaryClip(ClipData.newPlainText("多媒体娱乐屏连接诊断",diagnostics.toString()));notifyUser("已复制连接诊断，可粘贴发给我排查");}));gap(c,8);c.addView(button("打开系统蓝牙设置",false,()->{try{startActivity(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS));}catch(ActivityNotFoundException e){notifyUser("请手动打开手机蓝牙设置");}}));
        c=card(body);c.addView(text("字幕确认方式",16,INK,true));gap(c,10);Switch ack=new Switch(this);ack.setText("等待开发板回执");ack.setChecked(expectAck);ack.setEnabled(!link.isBusy());ack.setOnCheckedChangeListener((v,b)->{expectAck=b;persist();});c.addView(ack);gap(c,8);paragraph(c,"只接 TXD → 开发板输入时保持关闭。接好开发板输出 → HC-05 RXD，且固件支持回传后再开启。");
        LinearLayout bleCard=card(body);bleCard.addView(text("BLE 数据通道",16,INK,true));gap(bleCard,8);channelSpinner=new Spinner(this);channelSpinner.setContentDescription("实际探测到的BLE串口通道");bleCard.addView(channelSpinner,new LinearLayout.LayoutParams(-1,dp(66)));updateChannels(ble.labels(),ble.selectedIndex());paragraph(bleCard,"已识别串口服务会自动选择。未知服务请先复制诊断，确认后再手动选择；不会自动写入未知特征。");
        paragraph(body,"先断开其他手机蓝牙串口APP，再在此连接。BLE会读取实际GATT服务；经典SPP使用串口服务。UART速率只影响模块与FPGA之间的数据，不决定手机的蓝牙连接。");
        paragraph(body,"需要配套蓝牙固件才能控制开发板。旧 bit 即使蓝牙连接成功也不会接收新增接口的数据。");
        paragraph(body,"切到后台会断开连接，不会持续后台发送；回到 APP 后手动重新连接。");
        if(permission())loadDevices();else{catalogStatus.setText("尚未获得附近设备权限");setDeviceNames(Collections.singletonList("先允许附近设备权限，再刷新"),0);}
    }
    private void setDeviceNames(List<String> names,int selection){if(deviceSpinner==null)return;deviceSpinner.setOnItemSelectedListener(null);ArrayAdapter<String> a=new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,names);deviceSpinner.setAdapter(a);deviceSpinner.setSelection(selection);deviceSpinner.setEnabled(!devices.isEmpty()&&!connection.equals("CONNECTING")&&!link.isConnected());deviceSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){public void onItemSelected(AdapterView<?> p,View v,int pos,long id){if(pos>=0&&pos<devices.size()&&permission())try{selectedMac=devices.get(pos).getAddress();}catch(SecurityException ignored){}}public void onNothingSelected(AdapterView<?> p){}});}
    @SuppressWarnings("MissingPermission") private void loadDevices(){
        if(deviceSpinner==null)return;devices.clear();List<String> names=new ArrayList<>();int chosen=0;String summary="尚未读取系统配对列表";
        try{if(adapter==null){names.add("此手机没有可用的经典蓝牙适配器");summary="没有可用蓝牙适配器";}else if(!adapter.isEnabled()){names.add("请先在系统设置开启蓝牙");summary="蓝牙未开启";}else{
            // Display the complete system list. Type reports must never hide a paired device.
            devices.addAll(adapter.getBondedDevices());devices.sort(Comparator.comparing(d->d.getAddress()));
            summary="系统返回 "+devices.size()+" 个已配对设备；未按名称或类型过滤";
            for(int i=0;i<devices.size();i++){BluetoothDevice d=devices.get(i);String n=d.getName();String label=(n==null?"未命名设备":n)+"\n"+d.getAddress()+" · "+deviceType(d.getType());names.add(label);logDiagnostic("配对设备="+label.replace('\n',' '));if(d.getAddress().equals(selectedMac))chosen=i;}
            if(names.isEmpty())names.add("尚无已配对设备，请先到系统设置配对 HC-05");
        }}catch(SecurityException e){names.clear();devices.clear();names.add("附近设备权限不可用，请重新授权");summary="配对列表读取被权限拒绝";}
        if(catalogStatus!=null)catalogStatus.setText(summary);logDiagnostic(summary);
        setDeviceNames(names,chosen);
    }
    private String deviceType(int type){switch(type){case BluetoothDevice.DEVICE_TYPE_CLASSIC:return "经典";case BluetoothDevice.DEVICE_TYPE_LE:return "系统标记BLE";case BluetoothDevice.DEVICE_TYPE_DUAL:return "双模";default:return "类型未知";}}
    @SuppressWarnings("MissingPermission") private void connectSelected(){
        if(adapter==null){notifyUser("手机不支持经典蓝牙");return;}
        try{if(!adapter.isEnabled()){notifyUser("请先开启手机蓝牙");return;}}catch(SecurityException e){notifyUser("蓝牙权限不可用");return;}
        if(deviceSpinner==null||devices.isEmpty()){notifyUser("请先配对并选择 HC-05");return;}
        int i=deviceSpinner.getSelectedItemPosition();if(i<0||i>=devices.size())return;
        BluetoothDevice device=devices.get(i);
        try{selectedMac=device.getAddress();logDiagnostic("系统报告设备类型="+deviceType(device.getType())+"；不据此阻止SPP尝试");if(scanPermission()){boolean cancelled=adapter.cancelDiscovery();logDiagnostic("停止设备搜索="+cancelled);}else logDiagnostic("未获得停止搜索权限；继续尝试连接");
            boolean useBle=transportMode==1||(transportMode==0&&device.getType()==BluetoothDevice.DEVICE_TYPE_LE);
            logDiagnostic("选择设备="+device.getName()+" / "+selectedMac+" / 协议="+(useBle?"BLE GATT":"经典 SPP")+" / 模式="+transportMode);
            link.disconnect();link=useBle?ble:spp;connection="DISCONNECTED";persist();if(useBle)ble.connect(device);else spp.connect(device,transportMode!=3);
        }catch(SecurityException e){detail="蓝牙权限不可用，请在系统应用设置允许附近设备后重试";logDiagnostic(detail);if(status!=null)status.setText(detail);notifyUser(detail);}
    }
    private void sendCaption(){
        if(!link.isConnected()){page=2;render();notifyUser("请先连接 HC-05");return;}
        if(!valid||link.isBusy())return;
        try{persist();CaptionRaster snapshot=CaptionRaster.render(draft,color);int id=++sequence&255;byte[] packet=CaptionProtocol.packet(snapshot.columns,speed,visible,color,id);
            detail=expectAck?"正在发送，随后等待开发板确认…":"正在发送字幕…";if(status!=null)status.setText(detail);
            if(!link.send(packet,id,expectAck)){detail="当前不可发送，请检查连接或等待上次发送完成";if(status!=null)status.setText(detail);}refreshButtons();
        }catch(IllegalArgumentException e){notifyUser(e.getMessage());}
    }
    private void refreshButtons(){for(Button b:remoteButtons)b.setEnabled(link.isConnected()&&!link.isBusy());if(sendButton!=null){sendButton.setEnabled(valid&&!link.isBusy()&&!connection.equals("CONNECTING")&&!connection.equals("SELECT_CHANNEL"));sendButton.setText(link.isBusy()?"正在发送…":link.isConnected()?"发送到开发板":"先连接蓝牙设备");}if(channelSpinner!=null)channelSpinner.setEnabled(link==ble&&!link.isBusy()&&!ble.labels().isEmpty()&&!connection.equals("CONNECTING"));}
    private void updateChannels(List<String> channels,int selected){if(channelSpinner==null)return;channelSpinner.setOnItemSelectedListener(null);List<String> labels=new ArrayList<>();labels.add("请选择已确认的串口数据通道");labels.addAll(channels);channelSpinner.setAdapter(new ArrayAdapter<String>(this,android.R.layout.simple_spinner_dropdown_item,labels));channelSpinner.setSelection(selected+1);channelSpinner.setEnabled(link==ble&&!link.isBusy()&&!channels.isEmpty()&&!connection.equals("CONNECTING"));channelSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener(){public void onItemSelected(AdapterView<?> p,View v,int pos,long id){if(pos>0&&link==ble&&pos-1!=ble.selectedIndex())ble.selectChannel(pos-1);}public void onNothingSelected(AdapterView<?> p){}});}
    private void logDiagnostic(String message){diagnostics.append(new java.text.SimpleDateFormat("HH:mm:ss",Locale.ROOT).format(new Date())).append(" ").append(message).append('\n');if(diagnostics.length()>6000)diagnostics.delete(0,diagnostics.length()-6000);}
    @Override public void state(String state,String message){connection=state;detail=UserFeedback.display(message);logDiagnostic(state+" "+message);if(badge!=null)badge.setText(state.equals("CONNECTED")?"● 数据通道就绪":state.equals("SELECT_CHANNEL")?"○ 待选通道":state.equals("CONNECTING")?"○ 连接中":"○ 未连接");if(status!=null)status.setText(detail);if(connectButton!=null)connectButton.setText(activeSession()?"断开 / 取消连接":"连接所选设备");if(deviceSpinner!=null)deviceSpinner.setEnabled(!devices.isEmpty()&&!activeSession());if(modeSpinner!=null)modeSpinner.setEnabled(!activeSession());refreshButtons();}
    @Override public void sent(String message,boolean verified){detail=UserFeedback.display(message);logDiagnostic("发送结果 verified="+verified+" "+message);if(status!=null){status.setText(detail);status.setTextColor(verified?0xff16775b:MUTED);}refreshButtons();if(UserFeedback.needsToast(message,verified))notifyUser(detail);}
    private void persist(){prefs.edit().putString("draft",draft).putInt("speed",speed).putInt("color",color).putBoolean("visible",visible).putBoolean("ack",expectAck).putInt("transport_mode",transportMode).putString("device",selectedMac).apply();}
    @Override protected void onResume(){super.onResume();if(page==2&&permission())loadDevices();}
    @Override protected void onPause(){persist();super.onPause();}
    @Override protected void onStop(){super.onStop();if(link!=null)link.disconnect();}
    @Override protected void onDestroy(){handler.removeCallbacksAndMessages(null);if(spp!=null)spp.shutdown();if(ble!=null)ble.shutdown();super.onDestroy();}
}
