package cn.suki.remote;

import android.content.Context;
import android.graphics.*;
import android.view.View;

public final class CaptionPreview extends View {
    private final Paint paint=new Paint();private Bitmap bitmap;private boolean visible=true;private int speed=2;
    private long start=android.os.SystemClock.uptimeMillis();
    public CaptionPreview(Context context){super(context);setContentDescription("与开发板字模一致的滚动字幕预览");}
    public void update(CaptionRaster raster,boolean show,int speed){bitmap=raster.bitmap;visible=show;this.speed=speed;start=android.os.SystemClock.uptimeMillis();invalidate();}
    @Override protected void onDraw(Canvas c){super.onDraw(c);float d=getResources().getDisplayMetrics().density;
        paint.setAntiAlias(true);paint.setColor(Color.rgb(24,56,67));c.drawRoundRect(0,0,getWidth(),getHeight(),18*d,18*d,paint);
        paint.setColor(Color.rgb(147,181,190));paint.setTextSize(10*d);c.drawText("SCREEN PREVIEW / 字幕预览",18*d,25*d,paint);
        paint.setColor(Color.rgb(184,255,217));
        for(int i=0;i<16;i++){float h=(8+(i*17%26))*d;c.drawRoundRect((22+i*16)*d,82*d-h,(29+i*16)*d,82*d,3*d,3*d,paint);}
        paint.setColor(Color.rgb(15,39,48));c.drawRect(0,98*d,getWidth(),getHeight(),paint);
        if(visible&&bitmap!=null){float scale=1.25f*d;float cycle=getWidth()+bitmap.getWidth()*scale;
            float x=getWidth()-((android.os.SystemClock.uptimeMillis()-start)*.06f*speed*d)%cycle;
            paint.setFilterBitmap(false);c.drawBitmap(bitmap,null,new RectF(x,107*d,x+bitmap.getWidth()*scale,137*d),paint);}
        if(isShown()&&visible)postInvalidateOnAnimation();
    }
    @Override protected void onWindowVisibilityChanged(int visibility){super.onWindowVisibilityChanged(visibility);if(visibility==VISIBLE)invalidate();}
}
