package com.example.castlite

import com.example.castlite.casting.DiscoveryLifecycle
import com.example.castlite.casting.PlaybackState
import com.example.castlite.casting.dlna.DlnaCastTarget
import org.junit.Assert.*
import org.junit.Test

class DiscoveryLifecycleTest {
    @Test fun repeatedStartDoesNotCreateAnotherInitialization() {
        val lifecycle = DiscoveryLifecycle()
        val generation = lifecycle.begin()!!
        assertNull(lifecycle.begin())
        assertTrue(lifecycle.isCurrent(generation))
    }
    @Test fun lateInitializationAfterStopCannotPublishIntoNewSession() {
        val lifecycle = DiscoveryLifecycle()
        val old = lifecycle.begin()!!
        lifecycle.stop()
        val current = lifecycle.begin()!!
        assertFalse(lifecycle.isCurrent(old))
        assertTrue(lifecycle.isCurrent(current))
    }
    @Test fun dlnaReportsActualTransportStatesWithoutInventingUnknownSupport() {
        assertEquals(PlaybackState.PAUSED, DlnaCastTarget.transportPlaybackState("PAUSED_PLAYBACK"))
        assertEquals(PlaybackState.IDLE, DlnaCastTarget.transportPlaybackState("STOPPED"))
        assertEquals(PlaybackState.BUFFERING, DlnaCastTarget.transportPlaybackState("TRANSITIONING"))
        assertEquals(PlaybackState.PLAYING, DlnaCastTarget.transportPlaybackState("PLAYING"))
        assertNull(DlnaCastTarget.transportPlaybackState("vendor-state"))
    }
}
