package com.cinemax.cinemax

import android.net.Uri
import androidx.media3.common.C
import androidx.media3.datasource.BaseDataSource
import androidx.media3.datasource.DataSpec
import com.ciney.embedmedia.BrowserMediaTransport
import java.io.IOException
import java.io.InputStream

/** Native HLS parser/decoder; bytes fetched in the already validated browser. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
internal class BrowserSessionDataSource(
    private val transport: BrowserMediaTransport, private val page: String,
) : BaseDataSource(true) {
    private var input: InputStream? = null
    private var uri: Uri? = null
    private var remaining = C.LENGTH_UNSET.toLong()
    private var opened = false
    override fun open(dataSpec: DataSpec): Long {
        transferInitializing(dataSpec)
        uri = dataSpec.uri
        val end = if (dataSpec.length == C.LENGTH_UNSET.toLong()) "" else
            (dataSpec.position + dataSpec.length - 1).toString()
        val range = if (dataSpec.position > 0 || dataSpec.length != C.LENGTH_UNSET.toLong())
            "bytes=${dataSpec.position}-$end" else null
        val response = transport.fetch(page, dataSpec.uri.toString(), range)
        input = response.body
        if (response.url.startsWith("https://") || response.url.startsWith("http://")) uri = Uri.parse(response.url)
        if (response.status !in 200..299) {
            close(); throw IOException("Browser HTTP ${response.status}")
        }
        // A server may ignore Range. Skip safely instead of decoding wrong bytes.
        if (response.status == 200 && dataSpec.position > 0) {
            val scratch = ByteArray(8192)
            var skip = dataSpec.position
            while (skip > 0) {
                val count = input!!.read(scratch, 0, minOf(skip, scratch.size.toLong()).toInt())
                if (count < 0) { close(); throw IOException("Range outside resource") }
                skip -= count
            }
        }
        remaining = dataSpec.length
        opened = true
        transferStarted(dataSpec)
        return remaining
    }
    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        if (remaining == 0L) return C.RESULT_END_OF_INPUT
        val size = if (remaining == C.LENGTH_UNSET.toLong()) length else minOf(length.toLong(), remaining).toInt()
        val count = input?.read(buffer, offset, size) ?: C.RESULT_END_OF_INPUT
        if (count > 0) { if (remaining > 0) remaining -= count; bytesTransferred(count) }
        return count
    }
    override fun getUri(): Uri? = uri
    override fun close() {
        try { input?.close() } finally {
            input = null; uri = null
            if (opened) { opened = false; transferEnded() }
        }
    }
}
