package com.example.castlite

import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

internal object CastRequestIntent {
    fun read(intent: Intent): CastRequest? {
        val payload = intent.getStringExtra(CastRequest.EXTRA) ?: return null
        require(payload.toByteArray(Charsets.UTF_8).size <= 250_000)
        return CastRequest.fromMap(jsonValue(JSONObject(payload)) as Map<*, *>)
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { jsonValue(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
        else -> value
    }
}
