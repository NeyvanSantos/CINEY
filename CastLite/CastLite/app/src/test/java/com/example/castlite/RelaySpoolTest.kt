package com.example.castlite

import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class RelaySpoolTest {
    @Test fun deliversFirstChunkBeforeProducerFinishesAndDeletesTemporaryFile() {
        val directory = Files.createTempDirectory("relay-test").toFile()
        val worker = Executors.newSingleThreadExecutor()
        try {
            RelaySpool(directory).use { body ->
                val read = worker.submit<String> { String(ByteArray(5).also { assertEquals(5, body.read(it)) }) }
                body.append("first".toByteArray())
                assertEquals("first", read.get(2, TimeUnit.SECONDS))
                body.append("second".toByteArray())
                body.finish()
                assertEquals("second", String(body.readBytes()))
            }
            assertTrue(directory.listFiles()!!.isEmpty())
        } finally { worker.shutdownNow(); directory.delete() }
    }

    @Test fun resourceLargerThanOldSixteenMegabyteLimitPreservesBytes() {
        val directory = Files.createTempDirectory("relay-test").toFile()
        try {
            RelaySpool(directory).use { body ->
                val block = ByteArray(1024 * 1024) { (it % 251).toByte() }
                repeat(18) { body.append(block) }
                body.finish()
                repeat(18) {
                    val actual = ByteArray(block.size)
                    var offset = 0
                    while (offset < actual.size) offset += body.read(actual, offset, actual.size - offset)
                    assertArrayEquals(block, actual)
                }
                assertEquals(-1, body.read())
            }
        } finally { directory.delete() }
    }

    @Test fun browserFailureIsNotReportedAsSuccessfulEndOfStream() {
        val directory = Files.createTempDirectory("relay-test").toFile()
        try {
            RelaySpool(directory).use { body ->
                body.finish(IOException("connection lost"))
                assertThrows(IOException::class.java) { body.read() }
            }
        } finally { directory.delete() }
    }
}
