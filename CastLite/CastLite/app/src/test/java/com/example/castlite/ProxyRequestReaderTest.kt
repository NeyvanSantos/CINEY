package com.example.castlite

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.IOException

class ProxyRequestReaderTest {
    @Test fun preservesRange() {
        val request = ProxyRequestReader.read("GET /token/source HTTP/1.1\r\nRange: bytes=12-\r\n\r\n".byteInputStream())
        assertEquals("bytes=12-", request.headers["range"])
        assertEquals("/token/source", request.target)
    }
    @Test(expected = IOException::class) fun rejectsUnboundedLine() {
        ProxyRequestReader.read(("GET /" + "x".repeat(9000)).byteInputStream())
    }
    @Test(expected = IOException::class) fun rejectsIncompleteHeaders() {
        ProxyRequestReader.read("GET /x HTTP/1.1\r\nHost: x".byteInputStream())
    }
    @Test(expected = IOException::class) fun enforcesTotalBytes() {
        ProxyRequestReader.read(("GET /x HTTP/1.1\r\n" + ("X: " + "a".repeat(7000) + "\r\n").repeat(5) + "\r\n").byteInputStream())
    }
    @Test(expected = IOException::class) fun enforcesDeadline() {
        ProxyRequestReader.read("GET /x HTTP/1.1\r\n\r\n".byteInputStream()) { throw IOException("Deadline") }
    }
}
