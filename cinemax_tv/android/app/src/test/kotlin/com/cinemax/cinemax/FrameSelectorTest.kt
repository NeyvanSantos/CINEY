package com.cinemax.cinemax

import com.ciney.embedmedia.FrameSelector
import org.junit.Assert.*
import org.junit.Test

class FrameSelectorTest {
    private val pages = linkedMapOf("https://ad.test/frame" to "https://ad.test",
        "https://provider.test/player/" to "https://provider.test")
    @Test fun rejectsUnregisteredOriginInsteadOfUsingAdvertisement() {
        assertNull(FrameSelector.findPage("https://unknown.test/player", pages))
        assertNull(FrameSelector.findPage("http://provider.test/player", pages))
    }
    @Test fun keepsTrailingSlashAndSameOriginSupport() {
        assertEquals("https://provider.test/player/", FrameSelector.findPage("https://provider.test/player", pages))
        assertEquals("https://provider.test/player/", FrameSelector.findPage("https://provider.test:443/other", pages))
    }
    @Test fun rejectsCredentialsInvalidSchemesAndPorts() {
        assertNull(FrameSelector.findPage("https://user@provider.test/player", pages))
        assertNull(FrameSelector.findPage("https://provider.test:444/player", pages))
        assertNull(FrameSelector.findPage("javascript:alert(1)", pages))
    }
}
