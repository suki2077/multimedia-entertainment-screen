package cn.suki.remote;

import android.graphics.*;

public final class CaptionRaster {
    public final int[] columns;
    public final Bitmap bitmap;
    private CaptionRaster(int[] columns,Bitmap bitmap){this.columns=columns;this.bitmap=bitmap;}
    public static CaptionRaster render(String text,int color) {
        text=text.replace('\n',' ').replace('\r',' ');
        Paint paint=new Paint();paint.setAntiAlias(false);paint.setSubpixelText(false);
        paint.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL));paint.setTextSize(18);
        int width=text.trim().isEmpty()?0:(int)Math.ceil(paint.measureText(text))+6;
        if(width>2048) throw new IllegalArgumentException("字幕超过 2048 像素，请缩短内容");
        Bitmap mask=Bitmap.createBitmap(Math.max(1,width),24,Bitmap.Config.ARGB_8888);
        Canvas c=new Canvas(mask);c.drawColor(Color.BLACK);paint.setColor(Color.WHITE);
        Paint.FontMetrics fm=paint.getFontMetrics();
        c.drawText(text,2,(24-(fm.descent-fm.ascent))/2-fm.ascent,paint);
        int[] columns=new int[width];int[] pixels=new int[Math.max(1,width)*24];mask.getPixels(pixels,0,mask.getWidth(),0,0,mask.getWidth(),24);
        for(int x=0;x<width;x++)for(int y=0;y<24;y++)if(Color.red(pixels[y*mask.getWidth()+x])>=128)columns[x]|=1<<y;
        // Preview is built from the exact bits being sent, not an unrelated font rendering.
        mask.eraseColor(Color.TRANSPARENT);
        for(int x=0;x<width;x++)for(int y=0;y<24;y++)if((columns[x]&(1<<y))!=0)mask.setPixel(x,y,color);
        return new CaptionRaster(columns,mask);
    }
}
