package cn.suki.remote;
public interface CaptionLink {
 boolean isConnected();
 boolean isBusy();
 void disconnect();
 void shutdown();
 boolean send(byte[] packet,int sequence,boolean expectAck);
}
