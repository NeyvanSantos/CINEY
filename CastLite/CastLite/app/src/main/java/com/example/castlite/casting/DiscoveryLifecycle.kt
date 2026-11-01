package com.example.castlite.casting

internal class DiscoveryLifecycle {
    private var generation = 0L
    private var started = false
    @Synchronized fun begin(): Long? {
        if (started) return null
        started = true
        return ++generation
    }
    @Synchronized fun isCurrent(value: Long): Boolean = started && value == generation
    @Synchronized fun stop() { generation++; started = false }
}
