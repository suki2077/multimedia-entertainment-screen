package cn.suki.remote;

/** User-facing wording only. Raw transport diagnostics and ACK state stay intact. */
public final class UserFeedback {
    private UserFeedback() {}

    public static boolean isUnconfirmedSend(String message) {
        return message != null && (message.contains("未等待回执")
                || message.contains("未收到FPGA回执")
                || message.startsWith("未收到开发板回执"));
    }

    public static String display(String message) {
        if (isUnconfirmedSend(message)) return "已发送，请查看屏幕效果";
        if (message != null && message.startsWith("BLE 数据通道已就绪"))
            return "蓝牙已连接，可以发送字幕或遥控指令";
        return message;
    }

    public static boolean needsToast(String message, boolean verified) {
        return !verified && !isUnconfirmedSend(message);
    }
}
