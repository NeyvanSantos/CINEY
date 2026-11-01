package com.example.castlite

import com.example.castlite.casting.PlaybackState
import org.junit.Assert.*
import org.junit.Test

class CastSessionPolicyTest {
    @Test fun externalPlayAfterConfirmedPauseRearmsMonitoring() {
        val intent = PlaybackIntent()
        intent.requestPause(true, 0)
        assertFalse(intent.shouldMonitor(PlaybackState.PAUSED, 1000))
        assertTrue(intent.shouldMonitor(PlaybackState.PLAYING, 2000))
    }
    @Test fun failedPauseCommandDoesNotDisableMonitoringForever() {
        val intent = PlaybackIntent()
        intent.requestPause(true, 0)
        assertFalse(intent.shouldMonitor(PlaybackState.PLAYING, 2000))
        assertTrue(intent.shouldMonitor(PlaybackState.PLAYING, 8000))
    }
    @Test fun persistentDenialRequiresSourceActionAfterGracePeriod() {
        val guard = SourceAccessGuard()
        guard.denied(0)
        assertFalse(guard.observe(7000, PlaybackState.BUFFERING, 0))
        assertTrue(guard.observe(8000, PlaybackState.IDLE, 0))
    }
    @Test fun isolatedSegmentFailureDoesNotInterruptAdvancingPlayback() {
        val guard = SourceAccessGuard()
        guard.denied(0)
        assertFalse(guard.observe(1000, PlaybackState.PLAYING, 10000))
        assertFalse(guard.observe(10000, PlaybackState.PLAYING, 19000))
        assertFalse(guard.observe(20000, PlaybackState.BUFFERING, 19000))
    }
    @Test fun repeatedDenialsDoNotPostponeTheDeadline() {
        val guard = SourceAccessGuard()
        guard.denied(0)
        guard.denied(7000)
        assertTrue(guard.observe(8000, PlaybackState.ERROR, 0))
    }
    @Test fun explicitSeekWaitsForDestinationRatherThanOldPlayingStatus() {
        val policy = PlaybackRecovery(0, 11000)
        policy.seekTo(1000, 80000)
        policy.observe(2000, true, PlaybackState.PLAYING, 12000, 100000, false, false)
        assertEquals(80000L, policy.positionMs)
        assertEquals(PlaybackRecovery.Action.RELOAD,
            policy.observe(46000, true, PlaybackState.BUFFERING, 12000, 100000, false, false))
    }
}
