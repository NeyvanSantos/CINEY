package com.cinemax.cinemax

import org.junit.Assert.*
import org.junit.Test

class TvControlsAutoHideTest {
    private class Fixture {
        var now = 0L
        var hidden = 0
        val pending = linkedMapOf<Runnable, Long>()
        val policy = TvControlsAutoHide(
            { task, delay -> pending[task] = now + delay },
            { task -> pending.remove(task); Unit },
            { hidden++ },
        )
        fun advance(ms: Long) {
            now += ms
            pending.filterValues { it <= now }.keys.toList().forEach { task ->
                pending.remove(task)
                task.run()
            }
        }
    }

    @Test fun hidesAfterFiveSecondsWithoutDependingOnPlayOrPause() {
        val f = Fixture()
        f.policy.onInteraction()
        f.advance(4999)
        assertEquals(0, f.hidden)
        f.advance(1)
        assertEquals(1, f.hidden)
    }

    @Test fun qualityBrightnessAndRemoteActionsRenewOneDeadline() {
        val f = Fixture()
        repeat(4) {
            f.policy.onInteraction()
            assertEquals(1, f.pending.size)
            f.advance(4000)
            assertEquals(0, f.hidden)
        }
        f.advance(1000)
        assertEquals(1, f.hidden)
    }

    @Test fun doesNotHideDuringContinuousSliderTouch() {
        val f = Fixture()
        f.policy.onInteraction()
        f.policy.onTouchStarted()
        f.advance(10000)
        f.policy.onInteraction()
        assertEquals(0, f.hidden)
        assertTrue(f.pending.isEmpty())
        f.policy.onTouchFinished()
        f.advance(5000)
        assertEquals(1, f.hidden)
    }

    @Test fun hiddenControlsAndReleasedActivityCancelPendingCallbacks() {
        val f = Fixture()
        f.policy.onInteraction()
        f.policy.onHidden()
        f.advance(5000)
        assertEquals(0, f.hidden)
        f.policy.onInteraction()
        val stale = f.pending.keys.single()
        f.policy.release()
        f.policy.onInteraction()
        stale.run()
        assertTrue(f.pending.isEmpty())
        assertEquals(0, f.hidden)
    }
}
