package com.cinemax.cinemax

import org.junit.Assert.*
import org.junit.Test

class TvPlaybackOptionsTest {
    @Test fun keepsSessionForAuthenticationRequiredByLaterSegments() {
        val session = TvBrowserSessionState()
        assertFalse(session.canReleaseBrowser(false, false))
        assertFalse(session.canReleaseBrowser(true, false))
        assertFalse(session.canReleaseBrowser(false, true))
        assertFalse(session.canReleaseBrowser(true, true))
        session.requireBrowser()
        assertFalse(session.canReleaseBrowser(true, true))
    }

    @Test fun retainsBrowserWhenAnyResourceNeededAuthenticatedFallback() {
        val session = TvBrowserSessionState()
        session.requireBrowser()
        assertFalse(session.canReleaseBrowser(true, true))
    }

    @Test fun offersOnlyResolutionsActuallySupportedByTheSource() {
        val options = TvPlaybackOptions.available(listOf(
            TvVideoRendition(0, 0, 640, 360, 400000),
            TvVideoRendition(0, 1, 1280, 720, 1800000),
            TvVideoRendition(0, 2, 1920, 1080, 5000000, supported = false),
        ))
        assertEquals(listOf(720, 360), options.map { it.height })
    }

    @Test fun doesNotFabricateHdWhenSourceOffersOnly240p() {
        val options = TvPlaybackOptions.available(listOf(TvVideoRendition(0, 0, 426, 240, 150000)))
        assertEquals(listOf(240), options.map { it.height })
    }

    @Test fun deduplicatesSameResolutionAndKeepsHighestBitrateChoice() {
        val options = TvPlaybackOptions.available(listOf(
            TvVideoRendition(0, 0, 1280, 720, 800000),
            TvVideoRendition(1, 0, 1280, 720, 1800000),
            TvVideoRendition(0, 2, -1, -1, -1),
        ))
        assertEquals(1, options.size)
        assertEquals(1, options.single().group)
    }

    @Test fun offers1080pWhenTheSourceAndDecoderSupportIt() {
        val options = TvPlaybackOptions.available(listOf(TvVideoRendition(0, 0, 1920, 1080, 5000000)))
        assertEquals(listOf(1080), options.map { it.height })
    }

    @Test fun brightnessStartsUnchangedAndClampsUserInputToSafeIntensity() {
        assertEquals(0f, TvPlaybackOptions.brightness(0), 0f)
        assertEquals(0f, TvPlaybackOptions.brightness(-10), 0f)
        assertEquals(0.15f, TvPlaybackOptions.brightness(50), 0.0001f)
        assertEquals(0.30f, TvPlaybackOptions.brightness(100), 0.0001f)
        assertEquals(0.30f, TvPlaybackOptions.brightness(1000), 0.0001f)
    }
}
