package com.example.castlite

import java.io.Closeable
import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.thread
import org.junit.Assert.*
import org.junit.Test

class RelayHttpSourceTest {
    private class Origin(private val responses: List<String>) : Closeable {
        private val socket = ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"))
        val requests = CopyOnWriteArrayList<String>()
        val url = "http://127.0.0.1:${socket.localPort}/video"
        private val worker = thread(isDaemon = true) {
            try {
                responses.forEach { response ->
                    socket.accept().use { client ->
                        val reader = client.getInputStream().bufferedReader()
                        val lines = mutableListOf<String>()
                        while (true) {
                            val line = reader.readLine() ?: break
                            if (line.isBlank()) break
                            lines += line
                        }
                        requests += lines.joinToString("\n")
                        client.getOutputStream().write(response.toByteArray(Charsets.US_ASCII))
                        client.getOutputStream().flush()
                    }
                }
            } catch (_: IOException) { /* close terminates an unused accept */ }
        }
        override fun close() { socket.close(); worker.join(2_000) }
    }

    @Test fun retriesTemporaryOriginErrorsWithoutChangingMedia() {
        Origin(listOf("HTTP/1.1 503 Unavailable\r\nContent-Length: 0\r\n\r\n",
            "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nmovie")).use { origin ->
            RelayHttpSource(origin.url, "GET", mapOf("Cookie" to "session=test"), 0).use { source ->
                assertEquals("movie", source.stream().bufferedReader().readText())
                assertEquals(2, origin.requests.size)
                assertTrue(origin.requests.all { it.contains("Cookie: session=test") })
            }
        }
    }

    @Test fun resumesTruncatedBodyAtExactOffsetWithoutRepeatingBytes() {
        Origin(listOf("HTTP/1.1 200 OK\r\nContent-Length: 10\r\nETag: \"same\"\r\n\r\nabcde",
            "HTTP/1.1 206 Partial Content\r\nContent-Length: 5\r\nContent-Range: bytes 5-9/10\r\nETag: \"same\"\r\n\r\nfghij")).use { origin ->
            RelayHttpSource(origin.url, "GET", emptyMap(), 0).use { source ->
                assertEquals("abcdefghij", source.stream().bufferedReader().readText())
                assertTrue(origin.requests[1].contains("Range: bytes=5-9"))
                assertTrue(origin.requests[1].contains("If-Range: \"same\""))
            }
        }
    }

    @Test fun resumesReceiverRangeWithAbsoluteOffset() {
        Origin(listOf("HTTP/1.1 206 Partial Content\r\nContent-Length: 10\r\nContent-Range: bytes 100-109/200\r\n\r\nabcde",
            "HTTP/1.1 206 Partial Content\r\nContent-Length: 5\r\nContent-Range: bytes 105-109/200\r\n\r\nfghij")).use { origin ->
            RelayHttpSource(origin.url, "GET", mapOf("Range" to "bytes=100-109"), 0).use { source ->
                assertEquals("abcdefghij", source.stream().bufferedReader().readText())
                assertTrue(origin.requests[1].contains("Range: bytes=105-109"))
            }
        }
    }

    @Test fun rejectsOriginThatIgnoresResumeRange() {
        Origin(listOf("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabcde",
            "HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nabcdefghij")).use { origin ->
            RelayHttpSource(origin.url, "GET", emptyMap(), 0).use { source ->
                assertThrows(IOException::class.java) { source.stream().readBytes() }
            }
        }
    }

    @Test fun doesNotRetryAuthorizationFailure() {
        Origin(listOf("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")).use { origin ->
            RelayHttpSource(origin.url, "GET", emptyMap(), 0).use { source ->
                assertEquals(403, source.connection.responseCode)
                assertEquals(1, origin.requests.size)
            }
        }
    }
}
