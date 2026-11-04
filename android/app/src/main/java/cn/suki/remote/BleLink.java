package cn.suki.remote;

import android.bluetooth.*;
import android.content.Context;
import android.os.*;
import java.util.*;

/** All GATT state is serialized on the main Handler. No guessed handles, scans or auto-retries. */
@SuppressWarnings({"MissingPermission","deprecation"})
public final class BleLink implements CaptionLink {
 public interface Observer {void trace(String text);void channels(List<String> choices,int selected);}
 private static final UUID CCCD=uuid("2902"),FFE0=uuid("ffe0"),FFE1=uuid("ffe1");
 private static final UUID NUS=UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e"),NUS_WRITE=UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e"),NUS_NOTIFY=UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
 private final Context context;private final SppLink.Listener listener;private final Observer observer;
 private final Handler main=new Handler(Looper.getMainLooper());
 private BluetoothGatt gatt;private int session;private boolean ready,notifyReady,busy,closed,subscribing;
 private final List<Channel> channels=new ArrayList<>();private Channel selected;private int selectedIndex=-1;
 private byte[] packet;private int offset,nextOffset,sequence,earlyAckCode;private boolean expectAck,writePending,writesDone,earlyAck;private int writeType;
 private long writeStarted;private Runnable connectTimeout,writeTimeout,ackTimeout,settleTimeout;
 private CaptionProtocol.AckParser parser=new CaptionProtocol.AckParser();
 private static final class Channel {
  BluetoothGattCharacteristic write,notify;String label;boolean known;
  Channel(BluetoothGattCharacteristic w,BluetoothGattCharacteristic n,String l,boolean k){write=w;notify=n;label=l;known=k;}
 }
 public BleLink(Context context,SppLink.Listener listener,Observer observer){this.context=context.getApplicationContext();this.listener=listener;this.observer=observer;}
 static UUID uuid(String s){return UUID.fromString("0000"+s+"-0000-1000-8000-00805f9b34fb");}
 @Override public boolean isConnected(){return ready&&gatt!=null;}
 @Override public boolean isBusy(){return busy;}
 private void emit(String state,String detail){listener.state(state,detail);}
 private boolean current(int token,BluetoothGatt remote){return !closed&&token==session&&remote==gatt;}
 private void remove(Runnable action){if(action!=null)main.removeCallbacks(action);}
 private void cancelTimers(){remove(connectTimeout);remove(writeTimeout);remove(ackTimeout);remove(settleTimeout);}
 private void closeCurrent(){BluetoothGatt old=gatt;gatt=null;if(old!=null){try{old.disconnect();}catch(SecurityException ignored){}try{old.close();}catch(Exception ignored){}}}
 @Override public void disconnect(){session++;cancelTimers();ready=false;busy=false;notifyReady=false;subscribing=false;packet=null;writePending=false;selected=null;selectedIndex=-1;channels.clear();closeCurrent();observer.channels(Collections.emptyList(),-1);if(!closed)emit("DISCONNECTED","BLE 已断开");}
 @Override public void shutdown(){disconnect();closed=true;main.removeCallbacksAndMessages(null);}
 private void fail(String reason){disconnect();if(!closed)emit("DISCONNECTED",reason);}
 public List<String> labels(){List<String> out=new ArrayList<>();for(Channel c:channels)out.add(c.label);return out;}
 public int selectedIndex(){return selectedIndex;}
 public void connect(BluetoothDevice device){
  disconnect();if(closed)return;final int token=session;
  emit("CONNECTING","正在建立 BLE GATT 连接并探测服务（最长30秒）");
  BluetoothGattCallback callback=new BluetoothGattCallback(){
   @Override public void onConnectionStateChange(BluetoothGatt remote,int status,int newState){main.post(()->{
    if(!current(token,remote))return;observer.trace("BLE 连接回调 status="+status+" state="+newState);
    if(status!=BluetoothGatt.GATT_SUCCESS){fail("BLE 连接失败，GATT status="+status+"；请断开其他APP后重试");return;}
    if(newState==BluetoothProfile.STATE_CONNECTED){emit("CONNECTING","BLE 链路已连接，正在读取实际服务");try{if(!remote.discoverServices())fail("BLE 服务探测未能启动，请重连");}catch(SecurityException e){fail("BLE 服务探测权限不可用");}}
    else if(newState==BluetoothProfile.STATE_DISCONNECTED)fail("BLE 链路已断开");
   });}
   @Override public void onServicesDiscovered(BluetoothGatt remote,int status){main.post(()->{if(current(token,remote))discovered(token,remote,status);});}
   @Override public void onDescriptorWrite(BluetoothGatt remote,BluetoothGattDescriptor d,int status){main.post(()->{
    if(!current(token,remote)||!subscribing)return;subscribing=false;remove(writeTimeout);notifyReady=status==BluetoothGatt.GATT_SUCCESS;
    observer.trace("BLE 通知订阅 status="+status);markReady();
   });}
   @Override public void onCharacteristicWrite(BluetoothGatt remote,BluetoothGattCharacteristic c,int status){main.post(()->{
    if(!current(token,remote)||selected==null||c!=selected.write||packet==null||!busy)return;
    if(status!=BluetoothGatt.GATT_SUCCESS){fail("BLE 数据写入失败，GATT status="+status+"；本条未确认");return;}
    if(writeType==BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT&&writePending){writePending=false;remove(writeTimeout);offset=nextOffset;scheduleNext(token,remote);}
   });}
   @Override public void onCharacteristicChanged(BluetoothGatt remote,BluetoothGattCharacteristic c,byte[] value){final byte[] copy=value.clone();main.post(()->{if(current(token,remote))received(c,copy);});}
   @Override public void onCharacteristicChanged(BluetoothGatt remote,BluetoothGattCharacteristic c){if(Build.VERSION.SDK_INT<33){byte[] value=c.getValue();if(value!=null){final byte[] copy=value.clone();main.post(()->{if(current(token,remote))received(c,copy);});}}}
  };
  try{
   gatt=device.connectGatt(context,false,callback,BluetoothDevice.TRANSPORT_LE,BluetoothDevice.PHY_LE_1M_MASK,main);
   if(gatt==null){fail("系统未创建 BLE GATT 连接");return;}
   connectTimeout=()->{if(token==session&&!ready)fail("BLE 连接/服务探测超时，请复制连接诊断");};main.postDelayed(connectTimeout,30000);
  }catch(SecurityException e){fail("BLE 连接权限不可用，请允许附近设备权限");}
 }
 private static boolean writable(BluetoothGattCharacteristic c){return (c.getProperties()&(BluetoothGattCharacteristic.PROPERTY_WRITE|BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE))!=0;}
 private static boolean notifiable(BluetoothGattCharacteristic c){return (c.getProperties()&(BluetoothGattCharacteristic.PROPERTY_NOTIFY|BluetoothGattCharacteristic.PROPERTY_INDICATE))!=0;}
 private void discovered(int token,BluetoothGatt remote,int status){
  if(status!=BluetoothGatt.GATT_SUCCESS){fail("读取 BLE 服务失败，status="+status);return;}
  channels.clear();int known=-1;
  for(BluetoothGattService service:remote.getServices()){
   observer.trace("BLE 服务 "+service.getUuid());
   for(BluetoothGattCharacteristic c:service.getCharacteristics())observer.trace("  特征 "+c.getUuid()+" properties=0x"+Integer.toHexString(c.getProperties()));
   // Standard GAP/GATT/device/battery services are not UART transmit targets.
   if(service.getUuid().toString().startsWith("000018"))continue;
   for(BluetoothGattCharacteristic w:service.getCharacteristics()){
    if(!writable(w))continue;BluetoothGattCharacteristic n=null;boolean recognized=false;
    if(service.getUuid().equals(FFE0)&&w.getUuid().equals(FFE1)){if(notifiable(w))n=w;recognized=true;}
    else if(service.getUuid().equals(NUS)&&w.getUuid().equals(NUS_WRITE)){BluetoothGattCharacteristic candidate=service.getCharacteristic(NUS_NOTIFY);if(candidate!=null&&notifiable(candidate)){n=candidate;recognized=true;}}
    if(n==null&&notifiable(w))n=w;
    if(n==null){BluetoothGattCharacteristic only=null;int count=0;for(BluetoothGattCharacteristic candidate:service.getCharacteristics())if(notifiable(candidate)){only=candidate;count++;}if(count==1)n=only;}
    String label=(recognized?"串口 ":"手动 ")+service.getUuid()+" / 写 "+w.getUuid()+" / "+(n==null?"无通知":"通知 "+n.getUuid());
    channels.add(new Channel(w,n,label,recognized));if(recognized&&known==-1)known=channels.size()-1;
   }
  }
  remove(connectTimeout);observer.channels(labels(),-1);
  if(channels.isEmpty()){emit("SELECT_CHANNEL","BLE 已连接，但未发现可写的自定义数据特征；请复制连接诊断");return;}
  if(known>=0)selectChannel(known);
  else emit("SELECT_CHANNEL","BLE 服务已读出；未识别串口协议。请先复制诊断确认，或手动选择已知串口通道");
 }
 public void selectChannel(int index){
  if(gatt==null||closed||busy||subscribing||index<0||index>=channels.size())return;
  selected=channels.get(index);selectedIndex=index;ready=false;notifyReady=false;subscribing=true;parser=new CaptionProtocol.AckParser();
  final BluetoothGatt remote=gatt;final int token=session;emit("CONNECTING","已选择 BLE 数据通道，正在准备通知回传");observer.trace("BLE 选择 "+selected.label);observer.channels(labels(),index);
  if(selected.notify==null){subscribing=false;markReady();return;}
  try{
   BluetoothGattDescriptor descriptor=selected.notify.getDescriptor(CCCD);
   if(descriptor==null||!remote.setCharacteristicNotification(selected.notify,true)){subscribing=false;observer.trace("BLE 通知不可订阅，仅单向发送");markReady();return;}
   byte[] enable=(selected.notify.getProperties()&BluetoothGattCharacteristic.PROPERTY_NOTIFY)!=0?BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE:BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;
   writeTimeout=()->{if(current(token,remote)&&subscribing)fail("BLE 通知订阅超时，请重连");};main.postDelayed(writeTimeout,5000);
   boolean accepted;
   if(Build.VERSION.SDK_INT>=33)accepted=remote.writeDescriptor(descriptor,enable)==BluetoothStatusCodes.SUCCESS;
   else{descriptor.setValue(enable);accepted=remote.writeDescriptor(descriptor);}
   if(!accepted){remove(writeTimeout);subscribing=false;observer.trace("BLE 通知写入未受理，仅单向发送");markReady();}
  }catch(SecurityException e){fail("BLE 通知设置权限不可用");}
 }
 private void markReady(){
  ready=true;try{gatt.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH);}catch(SecurityException ignored){}
  emit("CONNECTED","BLE 数据通道已就绪，"+(notifyReady?"已启用通知，可等待FPGA回执":"无通知回传；请关闭等待回执，效果需查看屏幕"));
 }
 @Override public boolean send(byte[] bytes,int id,boolean ack){
  if(!isConnected()||busy||selected==null)return false;
  if(ack&&!notifyReady){main.post(()->listener.sent("此 BLE 通道尚无通知回传，请关闭等待回执后发送",false));return false;}
  busy=true;packet=bytes.clone();offset=0;sequence=id&255;expectAck=ack;writePending=false;writesDone=false;earlyAck=false;parser=new CaptionProtocol.AckParser();
  writeType=(selected.write.getProperties()&BluetoothGattCharacteristic.PROPERTY_WRITE)!=0?BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT:BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE;
  writeNext(session,gatt);return true;
 }
 private void writeNext(int token,BluetoothGatt remote){
  if(!current(token,remote)||packet==null||writePending)return;
  if(offset==packet.length){finishWrites(token,remote);return;}
  // Default ATT MTU23 payload20, paced below the downstream 9600-baud UART.
  nextOffset=Math.min(offset+20,packet.length);byte[] chunk=Arrays.copyOfRange(packet,offset,nextOffset);writeStarted=SystemClock.uptimeMillis();writePending=true;
  try{
   boolean accepted;
   if(Build.VERSION.SDK_INT>=33)accepted=remote.writeCharacteristic(selected.write,chunk,writeType)==BluetoothStatusCodes.SUCCESS;
   else{selected.write.setWriteType(writeType);selected.write.setValue(chunk);accepted=remote.writeCharacteristic(selected.write);}
   if(!accepted){fail("BLE 未受理数据写入；为避免重复字节，本条停止，请重连重发");return;}
   if(writeType==BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE){writePending=false;offset=nextOffset;scheduleNext(token,remote);}
   else{writeTimeout=()->{if(current(token,remote)&&writePending)fail("BLE 分包写入回调超时，请重连");};main.postDelayed(writeTimeout,5000);}
  }catch(SecurityException e){fail("BLE 写入权限不可用");}
 }
 private void scheduleNext(int token,BluetoothGatt remote){
  // Twenty bytes take 20.84ms at 9600 8N1; guard reduces overflow on small module FIFOs.
  long delay=Math.max(0,writeStarted+25-SystemClock.uptimeMillis());main.postDelayed(()->writeNext(token,remote),delay);
 }
 private void finishWrites(int token,BluetoothGatt remote){
  if(packet==null||writesDone)return;writesDone=true;writePending=false;remove(writeTimeout);
  if(earlyAck){completeAck(earlyAckCode);return;}
  if(expectAck){ackTimeout=()->{if(current(token,remote)&&busy){packet=null;busy=false;listener.sent("BLE 数据已写出，但未收到FPGA回执；请检查UART速率和回传线",false);}};main.postDelayed(ackTimeout,12000);}
  else{settleTimeout=()->{if(current(token,remote)&&busy){packet=null;busy=false;listener.sent("BLE 数据已发送，未等待回执；请查看屏幕",false);}};main.postDelayed(settleTimeout,300);}
 }
 private void received(BluetoothGattCharacteristic characteristic,byte[] bytes){
  if(selected==null||selected.notify!=characteristic)return;
  StringBuilder raw=new StringBuilder();for(byte b:bytes)raw.append(String.format(java.util.Locale.ROOT,"%02X ",b&255));
  observer.trace("BLE 通知 "+bytes.length+" 字节: "+raw);
  parser.feed(bytes,bytes.length,(id,code)->{
   observer.trace("FPGA有效回执 seq="+id+" code="+code);
   if(!busy||packet==null||id!=sequence)return;
   // A notification can precede the final Android write callback. Finish local
   // writes before releasing busy, so no old pacing task can enter a new send.
   if(!writesDone){earlyAck=true;earlyAckCode=code;return;}
   completeAck(code);
  });
 }
 private void completeAck(int code){packet=null;busy=false;writePending=false;remove(writeTimeout);remove(ackTimeout);remove(settleTimeout);listener.sent(code==0?"开发板已确认接收（BLE回传）":"开发板拒绝数据，错误码 "+code,code==0);}
}
