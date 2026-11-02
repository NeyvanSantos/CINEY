package com.ciney.embedmedia;

import java.util.function.Consumer;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.Map;

/** Correlates browser pause acknowledgements without depending on Android UI classes. */
public final class PlaybackPauseRequests {
    private static final class Request {
        final String origin;
        final Consumer<Boolean> callback;
        Request(String origin, Consumer<Boolean> callback) {
            this.origin=origin; this.callback=callback;
        }
    }
    private final Map<String,Request> pending=new HashMap<>();
    private boolean closed;
    public void add(String id, String origin, Consumer<Boolean> callback) {
        synchronized(this) {
            if(!closed) { pending.put(id,new Request(origin,callback)); return; }
        }
        callback.accept(false);
    }
    public void complete(String id, String origin, boolean success) {
        Request request;
        synchronized(this) {
            request=pending.get(id);
            if(request==null || !request.origin.equals(origin)) return;
            pending.remove(id);
        }
        request.callback.accept(success);
    }
    public void timeout(String id) {
        Request request;
        synchronized(this) { request=pending.remove(id); }
        if(request!=null) request.callback.accept(false);
    }
    public void close() {
        ArrayList<Request> requests;
        synchronized(this) {
            closed=true; requests=new ArrayList<>(pending.values()); pending.clear();
        }
        for(Request request:requests) request.callback.accept(false);
    }
}
