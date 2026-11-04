package cn.suki.remote;

import android.bluetooth.*;
import android.os.Handler;
import android.os.Looper;
import java.io.*;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** One socket, one writer, session-tagged callbacks. No automatic retries or hidden queues. */
@SuppressWarnings("MissingPermission")
public final class SppLink implements CaptionLink {
    public interface Listener {void state(String state,String detail);void sent(String detail,boolean verified);}
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final ExecutorService worker=Executors.newSingleThreadExecutor();
    private final ScheduledExecutorService clock=Executors.newSingleThreadScheduledExecutor();
    private final Listener listener;private final AtomicBoolean busy=new AtomicBoolean();
    private volatile BluetoothSocket socket;private volatile boolean connected;private volatile int generation;
    private volatile int waiting=-1;private volatile ScheduledFuture<?> ackTimer;private volatile boolean closed;
    public SppLink(Listener listener){this.listener=listener;}
    public boolean isConnected(){return connected;}
    public boolean isBusy(){return busy.get();}
    private void state(int g,String s,String detail){ui.post(()->{if(g==generation&&!closed)listener.state(s,detail);});}
    private void result(int g,String detail,boolean verified){ui.post(()->{if(g==generation&&!closed)listener.sent(detail,verified);});}
    private static void close(BluetoothSocket s){if(s!=null)try{s.close();}catch(IOException ignored){}}
    public synchronized void disconnect(){generation++;connected=false;waiting=-1;busy.set(false);if(ackTimer!=null)ackTimer.cancel(false);close(socket);socket=null;state(generation,"DISCONNECTED","蓝牙已断开");}
    public void connect(BluetoothDevice device){connect(device,false);}
    /** Compatibility is an explicit UI choice, never a silent security downgrade. */
    public synchronized void connect(BluetoothDevice device,boolean compatible){
        disconnect();final int g=generation;final String mode=compatible?"兼容连接":"标准连接";
        state(g,"CONNECTING","正在"+mode+" "+safeName(device)+"（最长15秒）");
        worker.execute(()->{
            BluetoothSocket candidate=null;ScheduledFuture<?> deadline=null;
            final AtomicBoolean timedOut=new AtomicBoolean();
            try {
                UUID spp=UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
                candidate=compatible?device.createInsecureRfcommSocketToServiceRecord(spp):device.createRfcommSocketToServiceRecord(spp);
                synchronized(this){if(g!=generation){close(candidate);return;}socket=candidate;}
                final BluetoothSocket connecting=candidate;
                deadline=clock.schedule(()->{synchronized(this){if(g==generation&&!connected){timedOut.set(true);close(connecting);}}},15,TimeUnit.SECONDS);
                candidate.connect();deadline.cancel(false);
                synchronized(this){if(g!=generation){close(candidate);return;}connected=true;}
                state(g,"CONNECTED",mode+"成功："+safeName(device)+"，尚未确认开发板");
                final BluetoothSocket active=candidate;
                Thread reader=new Thread(()->read(g,active),"media-screen-spp-reader");reader.start();
            }catch(SecurityException e){fail(g,mode+"失败：附近设备权限不可用。"+errorDetail(e));}
            catch(IOException e){fail(g,mode+"失败："+(timedOut.get()?"15秒超时。":"")+errorDetail(e)+"。请确认其他蓝牙APP已断开，并可切换连接方式重试。");}
            finally{if(deadline!=null)deadline.cancel(false);}
        });
    }
    private static String errorDetail(Exception e){String s=e.getMessage();if(s==null)s="无详细错误";s=s.replace('\n',' ').replace('\r',' ');if(s.length()>180)s=s.substring(0,180);return e.getClass().getSimpleName()+": "+s;}
    private static String safeName(BluetoothDevice d){try{String n=d.getName();return n==null?d.getAddress():n;}catch(SecurityException e){return "蓝牙设备";}}
    private synchronized void fail(int g,String why){if(g!=generation||closed)return;generation++;connected=false;waiting=-1;busy.set(false);close(socket);socket=null;if(ackTimer!=null)ackTimer.cancel(false);state(generation,"DISCONNECTED",why);}
    private void read(int g,BluetoothSocket active){
        CaptionProtocol.AckParser parser=new CaptionProtocol.AckParser();byte[] data=new byte[256];
        try{InputStream in=active.getInputStream();int n;
            while((n=in.read(data))!=-1){if(g!=generation)return;parser.feed(data,n,(sequence,code)->ack(g,sequence,code));}
            fail(g,"模块连接已关闭，请重新连接");
        }catch(IOException e){fail(g,"蓝牙连接中断，请检查供电并重新连接");}
    }
    private synchronized void ack(int g,int sequence,int code){
        if(g!=generation||waiting!=sequence)return;
        waiting=-1;if(ackTimer!=null)ackTimer.cancel(false);busy.set(false);
        if(code==0)result(g,"开发板已确认接收",true);
        else result(g,"开发板拒绝数据，错误码 "+code+"，请重新发送",false);
    }
    public synchronized boolean send(byte[] packet,int sequence,boolean expectAck){
        if(!connected||closed||!busy.compareAndSet(false,true))return false;
        final int g=generation;final BluetoothSocket active=socket;
        waiting=sequence&255;
        worker.execute(()->{
            ScheduledFuture<?> deadline=clock.schedule(()->fail(g,"发送超时，已断开；请重新连接"),10,TimeUnit.SECONDS);
            try {
                if(g!=generation)return;
                OutputStream out=active.getOutputStream();
                for(int offset=0;offset<packet.length;offset+=256){if(g!=generation)return;out.write(packet,offset,Math.min(256,packet.length-offset));}
                out.flush();deadline.cancel(false);
                synchronized(this){
                    if(g!=generation)return;
                    if(!expectAck){
                        // Do not immediately queue another caption behind bytes still in HC-05.
                        // Allow estimated 8N1 wire time plus a frame/ACK guard; this is not proof of receipt.
                        long settleMillis=(packet.length*10000L+9599)/9600+250;
                        clock.schedule(()->{synchronized(this){if(g==generation&&connected&&waiting==(sequence&255)){waiting=-1;busy.set(false);result(g,"数据已发送，未等待回执；请查看屏幕",false);}}},settleMillis,TimeUnit.MILLISECONDS);
                    }
                    else if(waiting==(sequence&255)){
                        // Bluetooth flush only drains the phone buffer; HC-05 still serializes
                        // the frame at 9600 baud (up to 6.42 seconds for 2048 columns).
                        long ackSeconds=Math.max(5,((packet.length*10L+9599)/9600)+5);
                        ackTimer=clock.schedule(()->{synchronized(this){if(g==generation&&waiting==(sequence&255)){waiting=-1;busy.set(false);result(g,"未收到开发板回执：请检查 RXD 回传线、波特率和固件",false);}}},ackSeconds,TimeUnit.SECONDS);
                    }
                }
            }catch(IOException|SecurityException e){fail(g,"发送失败，连接已关闭，请重新连接");}
            finally{deadline.cancel(false);}
        });return true;
    }
    public synchronized void shutdown(){disconnect();closed=true;worker.shutdownNow();clock.shutdownNow();ui.removeCallbacksAndMessages(null);}
}
