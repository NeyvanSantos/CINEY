package com.cinemax.cinemax

import com.ciney.embedmedia.PlaybackPauseRequests
import org.junit.Assert.*
import org.junit.Test

class PlaybackPauseRequestsTest {
    @Test fun acceptsOnlyTheMatchingRequestAndFrameOriginOnce() {
        val requests = PlaybackPauseRequests()
        val results = mutableListOf<Boolean>()
        requests.add("one", "https://provider.test") { results.add(it) }
        requests.complete("other", "https://provider.test", true)
        requests.complete("one", "https://advert.test", true)
        assertTrue(results.isEmpty())
        requests.complete("one", "https://provider.test", true)
        requests.timeout("one")
        requests.complete("one", "https://provider.test", true)
        assertEquals(listOf(true), results)
    }

    @Test fun timesOutAndIgnoresLateAcknowledgements() {
        val requests = PlaybackPauseRequests()
        val results = mutableListOf<Boolean>()
        requests.add("one", "https://provider.test") { results.add(it) }
        requests.timeout("one")
        requests.complete("one", "https://provider.test", true)
        assertEquals(listOf(false), results)
    }

    @Test fun closingFailsPendingRequestsAndRejectsNewOnes() {
        val requests = PlaybackPauseRequests()
        val results = mutableListOf<Boolean>()
        requests.add("one", "https://provider.test") { results.add(it) }
        requests.close()
        requests.close()
        requests.add("two", "https://provider.test") { results.add(it) }
        assertEquals(listOf(false, false), results)
    }
}
