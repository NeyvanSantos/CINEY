package com.cinemax.cinemax

import android.net.Uri
import android.util.Log
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.HttpDataSource
import androidx.media3.datasource.TransferListener

/** Prefer native HTTP bytes; authenticated resources stay in the browser session. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
internal class SessionHttpDataSource(
    private val http: DataSource,
    private val browser: DataSource,
    private val browserRequired: () -> Unit = {},
) : DataSource {
    private var active = http

    override fun addTransferListener(listener: TransferListener) {
        http.addTransferListener(listener)
        browser.addTransferListener(listener)
    }

    override fun open(dataSpec: DataSpec): Long {
        // Public manifests also use HTTP. Retain the browser only if a real
        // authentication/HTML response demonstrates that the session is needed.
        active = http
        return try {
            val length = http.open(dataSpec)
            val html = http.responseHeaders.entries.any { (key, values) ->
                key.equals("Content-Type", ignoreCase = true) &&
                    values.any { it.contains("text/html", ignoreCase = true) }
            }
            if (html) {
                http.close()
                active = browser
                browserRequired()
                Log.i("CINEY_NATIVE", "sessionLoad=browser html")
                return browser.open(dataSpec)
            }
            Log.i("CINEY_NATIVE", "sessionLoad=http bytes=$length")
            length
        } catch (error: HttpDataSource.InvalidResponseCodeException) {
            if (error.responseCode != 401 && error.responseCode != 403) throw error
            http.close()
            active = browser
            browserRequired()
            Log.i("CINEY_NATIVE", "sessionLoad=browser status=${error.responseCode}")
            browser.open(dataSpec)
        }
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int =
        active.read(buffer, offset, length)

    override fun getUri(): Uri? = active.uri

    override fun getResponseHeaders(): Map<String, List<String>> = active.responseHeaders

    override fun close() = active.close()
}
