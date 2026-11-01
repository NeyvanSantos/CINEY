package com.example.castlite

import org.junit.Assert.*
import org.junit.Test

class RelayHeaderPolicyTest {
    private val headers = mapOf("Authorization" to "Bearer synthetic", "Cookie" to "session=synthetic",
        "Referer" to "https://player.test/watch", "Origin" to "https://player.test", "User-Agent" to "Test")

    @Test fun credentialsStayOnTheirOriginIncludingDefaultPort() {
        assertEquals(headers, RelayHeaderPolicy.forTarget(headers, "https://cdn.test/a", "https://cdn.test:443/b"))
    }

    @Test fun crossOriginKeepsPublicHeadersButDropsSecretsCaseInsensitively() {
        val scoped = RelayHeaderPolicy.forTarget(headers + ("cOoKiE" to "other=synthetic"),
            "https://cdn.test/a", "https://other.test/b")
        assertFalse(scoped.keys.any { it.equals("Authorization", true) || it.equals("Cookie", true) })
        assertEquals(headers["Referer"], scoped["Referer"])
        assertEquals(headers["Origin"], scoped["Origin"])
    }

    @Test fun subdomainPortAndDowngradeAreDifferentOrigins() {
        listOf("https://cdn.test.evil.test/b", "https://sub.cdn.test/b", "https://cdn.test:8443/b", "http://cdn.test/b")
            .forEach { target ->
                assertFalse(RelayHeaderPolicy.forTarget(headers, "https://cdn.test/a", target).containsKey("Cookie"))
            }
    }
}
