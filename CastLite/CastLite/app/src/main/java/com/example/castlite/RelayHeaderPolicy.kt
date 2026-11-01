package com.example.castlite

import java.net.URI

internal object RelayHeaderPolicy {
    fun forTarget(headers: Map<String, String>, source: String, target: String): Map<String, String> =
        if (sameOrigin(source, target)) headers else headers.filterKeys {
            !it.equals("Authorization", true) && !it.equals("Cookie", true)
        }

    fun sameOrigin(source: String, target: String): Boolean = runCatching {
        val a = URI(source)
        val b = URI(target)
        fun port(uri: URI) = if (uri.port >= 0) uri.port else if (uri.scheme.equals("https", true)) 443 else 80
        a.host != null && b.host != null && a.scheme.lowercase() in listOf("http", "https") &&
            a.scheme.equals(b.scheme, true) && a.host.equals(b.host, true) && port(a) == port(b)
    }.getOrDefault(false)
}
