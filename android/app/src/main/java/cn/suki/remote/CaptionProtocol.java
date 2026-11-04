package cn.suki.remote;

/** Pure Java codec shared by transport and host-side regression tests. */
public final class CaptionProtocol {
    private CaptionProtocol() {}
    public static int crc(byte[] bytes, int offset, int count) {
        int c=0xffff;
        for (int i=offset;i<offset+count;i++) {
            c^=(bytes[i]&255)<<8;
            for(int j=0;j<8;j++) c=((c&0x8000)!=0?(c<<1)^0x1021:c<<1)&0xffff;
        }
        return c;
    }
    public static byte[] packet(int[] columns,int speed,boolean visible,int color,int sequence) {
        if(columns==null || columns.length>2048 || speed<1 || speed>4) throw new IllegalArgumentException("字幕宽度或速度无效");
        int w=columns.length;
        byte[] p=new byte[13+3*w];
        p[0]=(byte)0xa5;p[1]=0x5a;p[2]=1;p[3]=(byte)sequence;
        p[4]=(byte)w;p[5]=(byte)(w>>8);p[6]=(byte)speed;p[7]=(byte)(visible?1:0);
        p[8]=(byte)(color>>16);p[9]=(byte)(color>>8);p[10]=(byte)color;
        for(int x=0;x<w;x++)for(int b=0;b<3;b++)p[11+3*x+b]=(byte)(columns[x]>>(8*b));
        int crc=crc(p,2,p.length-4);p[p.length-2]=(byte)(crc>>8);p[p.length-1]=(byte)crc;
        return p;
    }
    /** Version 2: A5 5A 02 sequence command CRC16. */
    public static byte[] remotePacket(int command,int sequence) {
        if(command<1 || command>15)throw new IllegalArgumentException("遥控命令无效");
        byte[] p={(byte)0xa5,0x5a,2,(byte)sequence,(byte)command,0,0};
        int c=crc(p,2,3);p[5]=(byte)(c>>8);p[6]=(byte)c;return p;
    }
    public interface AckConsumer {void accept(int sequence,int code);}
    /** Sliding window tolerates split packets, noise and bad CRC without false confirmation. */
    public static final class AckParser {
        private final byte[] window=new byte[6]; private int length;
        public void feed(byte[] data,int n,AckConsumer consumer) {
            for(int i=0;i<n;i++) {
                if(length==6){System.arraycopy(window,1,window,0,5);length=5;}
                window[length++]=data[i];
                if(length==6 && window[0]==0x5a && (window[1]&255)==0xa5 &&
                    crc(window,2,2)==(((window[4]&255)<<8)|(window[5]&255))) {
                    consumer.accept(window[2]&255,window[3]&255);length=0;
                }
            }
        }
    }
}
