package com.ciney.embedmedia;

import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.webkit.WebView;
import androidx.webkit.JavaScriptReplyProxy;
import androidx.webkit.WebViewCompat;
import androidx.webkit.WebViewFeature;
import org.json.JSONObject;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Bounded, browser-session transport. No HTTP listener or exported cookies. */
public final class BrowserMediaTransport implements Closeable {
    private static final Map<WebView, BrowserMediaTransport> INSTANCES = Collections.synchronizedMap(new WeakHashMap<>());
    private static final String BRIDGE = "CineyNativeFetch";
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Map<String, Frame> frames = new ConcurrentHashMap<>();
    private final Map<String, Pending> pending = new ConcurrentHashMap<>();
    private final Semaphore slots = new Semaphore(6);
    private final ExecutorService writes = Executors.newSingleThreadExecutor();
    private final File directory;
    private volatile boolean closed;
    private long confirmTime;
    public static void recordConfirm(WebView view) {
        BrowserMediaTransport t=get(view); if(t!=null) t.confirmTime=android.os.SystemClock.uptimeMillis();
    }
    public static boolean consumeConfirm(WebView view) {
        BrowserMediaTransport t=get(view); if(t==null) return false;
        long age=android.os.SystemClock.uptimeMillis()-t.confirmTime;
        boolean valid=t.confirmTime>0 && age<1500; t.confirmTime=0; return valid;
    }
    private static final class Frame {
        final String origin; final JavaScriptReplyProxy reply;
        Frame(String origin, JavaScriptReplyProxy reply) { this.origin = origin; this.reply = reply; }
    }
    public static final class Response {
        public final int status; public final long length; public final InputStream body; public final String url;
        Response(int status, long length, InputStream body, String url) { this.status=status; this.length=length; this.body=body; this.url=url; }
    }
    private static final class Pending {
        final Frame frame; final Spool spool; final CountDownLatch started = new CountDownLatch(1);
        final AtomicBoolean released = new AtomicBoolean(); volatile Response response;
        final long startMs = android.os.SystemClock.elapsedRealtime(); volatile long bytes;
        Pending(Frame frame, File dir) throws IOException { this.frame=frame; spool=new Spool(dir); }
    }
    public static void attach(WebView view) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER) || INSTANCES.containsKey(view)) return;
        BrowserMediaTransport transport = new BrowserMediaTransport(view.getContext().getCacheDir());
        WebViewCompat.addWebMessageListener(view, BRIDGE, Collections.singleton("*"),
            (webView, message, sourceOrigin, mainFrame, reply) -> transport.receive(message.getData(), sourceOrigin.toString(), reply));
        INSTANCES.put(view, transport);
    }
    public static BrowserMediaTransport get(WebView view) { return INSTANCES.get(view); }
    public static void detach(WebView view) {
        BrowserMediaTransport transport=INSTANCES.remove(view);
        if (transport!=null) { transport.close(); WebViewCompat.removeWebMessageListener(view, BRIDGE); }
    }
    private BrowserMediaTransport(File directory) { this.directory=directory; }
    private static boolean http(String url) {
        Uri uri=Uri.parse(url);
        return ("https".equals(uri.getScheme()) || "http".equals(uri.getScheme())) && uri.getHost()!=null && uri.getUserInfo()==null;
    }
    private static String origin(String page) {
        Uri u=Uri.parse(page); return u.getScheme()+"://"+u.getAuthority();
    }
    private Frame findFrame(String page) {
        if (page == null) return null;
        Frame f = frames.get(page);
        if (f != null) return f;
        String alt = page.endsWith("/") ? page.substring(0, page.length() - 1) : (page + "/");
        f = frames.get(alt);
        if (f != null) return f;
        String orig = origin(page);
        for (Map.Entry<String, Frame> entry : frames.entrySet()) {
            if (entry.getValue().origin.equals(orig)) return entry.getValue();
        }
        return frames.isEmpty() ? null : frames.values().iterator().next();
    }
    public boolean hasPage(String page) { return findFrame(page) != null; }
    public void pauseLocalPlayback() { broadcast("pauseLocal"); }
    public void resumeLocalPlayback() { broadcast("resumeLocal"); }
    private void broadcast(String kind) {
        ui.post(() -> { for(Frame frame:frames.values()) {
            try { frame.reply.postMessage(new JSONObject().put("kind",kind).toString()); } catch(Exception ignored) {}
        }});
    }
    public Response fetch(String page, String url, String range) throws IOException {
        Frame frame=findFrame(page);
        if (closed || frame==null || !http(url)) throw new IOException("Browser session unavailable");
        try { if(!slots.tryAcquire(15,TimeUnit.SECONDS)) throw new IOException("Browser transport busy"); }
        catch(InterruptedException e) { Thread.currentThread().interrupt(); throw new IOException("Interrupted"); }
        String id=UUID.randomUUID().toString();
        Pending request;
        try { request=new Pending(frame,directory); } catch(IOException e) { slots.release(); throw e; }
        pending.put(id,request);
        android.util.Log.i("CINEY_NATIVE", "browserLoad=begin id="+id.substring(0,8));
        ui.post(() -> {
            try { frame.reply.postMessage(new JSONObject().put("kind","fetch").put("id",id).put("url",url)
                .put("range",range==null?JSONObject.NULL:range).toString()); }
            catch(Exception e) { request.started.countDown(); }
        });
        boolean returned = false;
        try {
            request.started.await(45,TimeUnit.SECONDS);
            if(request.response==null) throw new IOException("Browser media request failed");
            returned = true;
            return request.response;
        } catch(InterruptedException e) { Thread.currentThread().interrupt(); throw new IOException("Interrupted"); }
        finally { if(!returned) release(id,request); }
    }
    private void receive(String raw, String source, JavaScriptReplyProxy reply) {
        if(closed || raw==null || raw.length()>100000) return;
        try {
            JSONObject data=new JSONObject(raw); String kind=data.optString("kind");
            if("hello".equals(kind)) {
                String page=data.optString("page");
                if(page.length()<=8192 && http(page) && origin(page).equals(source) && frames.size()<32)
                    frames.put(page,new Frame(source,reply));
                return;
            }
            String id=data.optString("id"); Pending request=pending.get(id);
            if(request==null || !request.frame.origin.equals(source)) return;
            switch(kind) {
                case "start":
                    int status=data.optInt("status"); long length=data.optLong("length",-1);
                    InputStream body=new FilterInputStream(request.spool) {
                        @Override public void close() { release(id,request); }
                    };
                    request.response=new Response(status,length,body,data.optString("url")); request.started.countDown(); break;
                case "chunk":
                    byte[] bytes=Base64.decode(data.getString("data"),Base64.DEFAULT);
                    // The per-block ACK bounds queued work. Never wait for disk
                    // writes on Android's UI thread while video is rendering.
                    writes.execute(() -> {
                        try {
                            if(request.released.get()) return;
                            request.spool.append(bytes); request.bytes+=bytes.length;
                            ui.post(() -> {
                                if(request.released.get()) return;
                                try { reply.postMessage(new JSONObject().put("kind","ack").put("id",id).toString()); }
                                catch(Exception error) { request.spool.finish(new IOException("Browser acknowledgement failed")); }
                            });
                        } catch(IOException error) { request.spool.finish(error); }
                    });
                    break;
                case "end":
                    android.util.Log.i("CINEY_NATIVE", "browserLoad=end id="+id.substring(0,8)+" bytes="+request.bytes+" elapsedMs="+(android.os.SystemClock.elapsedRealtime()-request.startMs));
                    request.spool.finish(null); break;
                case "error": android.util.Log.w("CINEY_NATIVE", "browserTransferError=" + data.optString("reason").replaceAll("[^A-Za-z]", "")); request.spool.finish(new IOException("Browser media transfer failed")); request.started.countDown(); break;
            }
        } catch(Exception e) { /* No browser tokens or URLs are logged. */ }
    }
    private void release(String id, Pending request) {
        if(!request.released.compareAndSet(false,true)) return;
        pending.remove(id); request.started.countDown();
        try { request.spool.close(); } catch(IOException ignored) {}
        slots.release();
        ui.post(() -> { try { request.frame.reply.postMessage(new JSONObject().put("kind","cancel").put("id",id).toString()); } catch(Exception ignored) {} });
    }
    @Override public void close() {
        closed=true; frames.clear();
        for(Map.Entry<String,Pending> entry:new ArrayList<>(pending.entrySet())) release(entry.getKey(),entry.getValue());
        writes.shutdownNow();
    }
    private static final class Spool extends InputStream {
        private final File file; private final RandomAccessFile writer; private final FileInputStream reader;
        private long written,consumed; private boolean ended,closed; private IOException failure;
        Spool(File directory) throws IOException {
            file=File.createTempFile("ciney-native-",".part",directory);
            writer=new RandomAccessFile(file,"rw"); reader=new FileInputStream(file);
        }
        synchronized void append(byte[] bytes) throws IOException {
            if(closed || ended || written+bytes.length>128L*1024*1024) throw new IOException("Browser resource limit");
            writer.write(bytes); written+=bytes.length; notifyAll();
        }
        synchronized void finish(IOException error) { ended=true; failure=error; notifyAll(); }
        @Override public int read() throws IOException { byte[] b=new byte[1]; return read(b,0,1)<0?-1:b[0]&255; }
        @Override public synchronized int read(byte[] bytes,int offset,int length) throws IOException {
            if(length==0) return 0;
            long deadline=System.nanoTime()+45_000_000_000L;
            while(written==consumed && !ended && !closed) {
                long remaining=(deadline-System.nanoTime())/1_000_000;
                if(remaining<=0) throw new IOException("Browser read timed out");
                try { wait(Math.max(1,remaining)); } catch(InterruptedException e) { Thread.currentThread().interrupt(); throw new IOException("Interrupted"); }
            }
            if(closed) throw new IOException("Closed");
            if(written==consumed) { if(failure!=null) throw failure; return -1; }
            int count=reader.read(bytes,offset,(int)Math.min(length,written-consumed));
            if(count>0) consumed+=count; return count;
        }
        @Override public synchronized void close() throws IOException {
            if(closed) return; closed=true;
            try { writer.close(); reader.close(); } finally { file.delete(); notifyAll(); }
        }
    }
}
