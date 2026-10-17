package com.example.castlite

import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile

/** Browser chunks can reach the TV immediately without buffering a segment in RAM. */
internal class RelaySpool(directory: File) : InputStream() {
    private val file = File.createTempFile("cast-relay-", ".part", directory)
    private val writer = RandomAccessFile(file, "rw")
    private val reader = FileInputStream(file)
    private val monitor = Object()
    private var written = 0L
    private var consumed = 0L
    private var completed = false
    private var closed = false
    private var failure: IOException? = null

    fun append(bytes: ByteArray) = synchronized(monitor) {
        if (closed || completed) throw IOException("Relay closed")
        if (written + bytes.size > 128L * 1024 * 1024) throw IOException("Relay resource too large")
        writer.write(bytes)
        written += bytes.size
        monitor.notifyAll()
    }

    fun finish(error: IOException? = null) = synchronized(monitor) {
        completed = true
        failure = error
        monitor.notifyAll()
    }

    override fun read(): Int {
        val single = ByteArray(1)
        return if (read(single, 0, 1) < 0) -1 else single[0].toInt() and 0xff
    }

    override fun read(bytes: ByteArray, offset: Int, count: Int): Int = synchronized(monitor) {
        if (count == 0) return 0
        val deadline = System.nanoTime() + 45_000_000_000L
        while (written == consumed && !completed && !closed) {
            val remaining = (deadline - System.nanoTime()) / 1_000_000
            if (remaining <= 0) throw IOException("Browser media read timed out")
            monitor.wait(remaining.coerceAtLeast(1))
        }
        if (closed) throw IOException("Relay closed")
        if (written == consumed) {
            failure?.let { throw it }
            return@synchronized -1
        }
        val read = reader.read(bytes, offset, minOf(count.toLong(), written - consumed).toInt())
        if (read > 0) consumed += read
        read
    }

    override fun close() = synchronized(monitor) {
        if (!closed) {
            closed = true
            writer.close()
            reader.close()
            if (!file.delete()) file.deleteOnExit()
            monitor.notifyAll()
        }
    }
}
