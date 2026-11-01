package com.ciney.embedmedia;

import java.net.URI;
import java.util.Locale;
import java.util.Map;

/** Selects only a registered page in the requested web origin. */
public final class FrameSelector {
    private FrameSelector() {}

    public static String findPage(String page, Map<String, String> registeredOrigins) {
        String requestedOrigin = origin(page);
        if (requestedOrigin == null) return null;
        String exactOrigin = registeredOrigins.get(page);
        if (requestedOrigin.equals(origin(exactOrigin))) return page;
        String alternate = page.endsWith("/") ? page.substring(0, page.length() - 1) : page + "/";
        if (requestedOrigin.equals(origin(registeredOrigins.get(alternate)))) return alternate;
        for (Map.Entry<String, String> entry : registeredOrigins.entrySet()) {
            if (requestedOrigin.equals(origin(entry.getValue()))) return entry.getKey();
        }
        return null;
    }

    private static String origin(String value) {
        if (value == null) return null;
        try {
            URI uri = new URI(value);
            String scheme = uri.getScheme();
            if (scheme == null || uri.getHost() == null || uri.getUserInfo() != null) return null;
            scheme = scheme.toLowerCase(Locale.ROOT);
            if (!scheme.equals("https") && !scheme.equals("http")) return null;
            int port = uri.getPort() == -1 ? (scheme.equals("https") ? 443 : 80) : uri.getPort();
            return scheme + "://" + uri.getHost().toLowerCase(Locale.ROOT) + ":" + port;
        } catch (Exception invalid) {
            return null;
        }
    }
}
