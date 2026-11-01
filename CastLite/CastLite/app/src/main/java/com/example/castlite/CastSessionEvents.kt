package com.example.castlite

import com.example.castlite.casting.CastTarget
import java.util.concurrent.CopyOnWriteArraySet

/** Estados públicos sem URLs, cookies ou cabeçalhos da origem. */
object CastSessionEvents {
    private val listeners = CopyOnWriteArraySet<(Map<String, Any?>) -> Unit>()
    @Volatile private var state: Map<String, Any?> = mapOf("state" to "idle")

    fun snapshot(): Map<String, Any?> = state.toMap()
    fun addListener(listener: (Map<String, Any?>) -> Unit) { listeners.add(listener) }
    fun removeListener(listener: (Map<String, Any?>) -> Unit) { listeners.remove(listener) }

    fun opening(request: CastRequest) = publish(mapOf(
        "state" to "resolving", "requestId" to request.requestId,
        "title" to request.title, "server" to request.source.server,
        "contentId" to request.contentId, "season" to request.season, "episode" to request.episode,
        "positionMs" to request.positionMs, "durationMs" to 0L
    ))

    fun update(target: CastTarget?) = publish((state - "error") + mapOf(
        "state" to (target?.playbackState?.name?.lowercase() ?: "idle"),
        "deviceName" to target?.name, "protocol" to target?.protocol?.name,
        "positionMs" to (target?.positionMs ?: 0L),
        "durationMs" to (target?.durationMs ?: 0L)
    ))

    fun error(code: String) = publish(state + mapOf("state" to "error", "error" to code))
    fun quality(value: String) = publish(state + mapOf("quality" to value))

    private fun publish(value: Map<String, Any?>) {
        state = value
        listeners.forEach { it(value.toMap()) }
    }
}
