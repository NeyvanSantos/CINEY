package com.example.castlite

import com.example.castlite.casting.PlaybackState
import org.junit.Assert.*
import org.junit.Test

class PlaybackRecoveryTest {
    @Test fun bufferingPositionIsUsedForRecovery() {
        val policy = PlaybackRecovery(0, 11000)
        policy.observe(2000, true, PlaybackState.BUFFERING, 80000, 300000, false, false)
        assertEquals(PlaybackRecovery.Action.RELOAD,
            policy.observe(47000, true, PlaybackState.BUFFERING, 80000, 300000, false, false))
        assertEquals(80000L, policy.positionMs)
    }

    @Test fun bufferingAfterSeekingBackFromEndStillRecovers() {
        val policy = PlaybackRecovery(0, 99000)
        assertEquals(PlaybackRecovery.Action.RELOAD,
            policy.observe(50000, true, PlaybackState.BUFFERING, 10000, 100000, false, false))
    }

    @Test fun waitsForStartupThenRetriesWithoutLosingPosition() {
        val policy = PlaybackRecovery(0, 123_000)
        assertEquals(PlaybackRecovery.Action.WAIT, policy.observe(44_000, true, PlaybackState.IDLE, 0, 0, false, false, true))
        assertEquals(PlaybackRecovery.Action.RELOAD, policy.observe(45_000, true, PlaybackState.IDLE, 0, 0, false, false, true))
        assertEquals(123_000L, policy.positionMs)
    }

    @Test fun stalledPlaybackResumesFromLastProgress() {
        val policy = PlaybackRecovery(0, 0)
        policy.observe(2_000, true, PlaybackState.PLAYING, 52_000, 300_000, false, false)
        assertEquals(PlaybackRecovery.Action.RELOAD, policy.observe(47_000, true, PlaybackState.BUFFERING, 0, 300_000, false, false))
        assertEquals(52_000L, policy.positionMs)
    }

    @Test fun pausesAndNormalStopsDoNotRestart() {
        val policy = PlaybackRecovery(0, 50_000)
        assertEquals(PlaybackRecovery.Action.WAIT, policy.observe(200_000, true, PlaybackState.PAUSED, 50_000, 300_000, false, false))
        assertEquals(PlaybackRecovery.Action.WAIT, policy.observe(400_000, true, PlaybackState.IDLE, 0, 300_000, false, false))
    }

    @Test fun completionDoesNotRestartFilm() {
        val policy = PlaybackRecovery(0, 299_000)
        assertEquals(PlaybackRecovery.Action.WAIT, policy.observe(100_000, true, PlaybackState.IDLE, 0, 300_000, true, false))
    }

    @Test fun disconnectedSessionWaitsForReconnectForUpToThreeMinutes() {
        val policy = PlaybackRecovery(0, 25_000)
        assertEquals(PlaybackRecovery.Action.WAIT, policy.observe(65_000, false, PlaybackState.IDLE, 0, 0, false, false))
        assertEquals(PlaybackRecovery.Action.RELOAD, policy.observe(70_000, true, PlaybackState.ERROR, 0, 0, true, false))
        val absent = PlaybackRecovery(0, 25_000)
        assertEquals(PlaybackRecovery.Action.EXHAUSTED, absent.observe(180_000, false, PlaybackState.IDLE, 0, 0, false, false))
    }

    @Test fun retriesAreBoundedAndResetAfterSustainedProgress() {
        val policy = PlaybackRecovery(0, 0)
        for (time in listOf(8_000L, 16_000L, 24_000L)) {
            assertEquals(PlaybackRecovery.Action.RELOAD, policy.observe(time, true, PlaybackState.ERROR, 0, 0, true, true))
        }
        assertEquals(PlaybackRecovery.Action.EXHAUSTED, policy.observe(32_000, true, PlaybackState.ERROR, 0, 0, true, true))
        policy.observe(34_000, true, PlaybackState.PLAYING, 1_000, 300_000, false, false)
        policy.observe(65_000, true, PlaybackState.PLAYING, 32_000, 300_000, false, false)
        assertEquals(PlaybackRecovery.Action.RELOAD, policy.observe(73_000, true, PlaybackState.ERROR, 0, 300_000, true, false))
    }
}
