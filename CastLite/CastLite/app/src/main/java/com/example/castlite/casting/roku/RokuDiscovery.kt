package com.example.castlite.casting.roku

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.example.castlite.casting.DeviceDiscovery
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.URI
import java.net.URL
import java.nio.charset.StandardCharsets
import javax.xml.parsers.DocumentBuilderFactory
import kotlin.concurrent.thread

/**
 * Discovers Roku devices on the local network using SSDP M-SEARCH with ST: roku:ecp.
 */
class RokuDiscovery(
    private val context: Context,
    private val deviceDiscovery: DeviceDiscovery
) {
    data class RokuDeviceInfo(val ip: String, val port: Int, val location: String, val friendlyName: String)

    @Volatile private var scanning = false
    private var multicastLock: WifiManager.MulticastLock? = null

    /** Start a background scan for Roku devices. Results are added to [deviceDiscovery]. */
    fun start() {
        if (scanning) return
        scanning = true
        acquireMulticastLock()
        thread(name = "CastLite-Roku-SSDP", isDaemon = true) {
            discoverDevices()
            scanning = false
        }
    }

    fun stop() {
        scanning = false
        releaseMulticastLock()
    }

    fun refresh() {
        stop()
        start()
    }

    private fun discoverDevices() {
        var socket: DatagramSocket? = null
        try {
            socket = DatagramSocket().apply {
                soTimeout = SOCKET_TIMEOUT_MS
                broadcast = true
            }

            val searchMessage = "M-SEARCH * HTTP/1.1\r\n" +
                "Host: $SSDP_ADDRESS:$SSDP_PORT\r\n" +
                "Man: \"ssdp:discover\"\r\n" +
                "ST: $ROKU_ST\r\n" +
                "MX: $MX_SECONDS\r\n" +
                "\r\n"

            val sendData = searchMessage.toByteArray(StandardCharsets.UTF_8)
            val sendPacket = DatagramPacket(
                sendData, sendData.size,
                InetAddress.getByName(SSDP_ADDRESS), SSDP_PORT
            )

            socket.send(sendPacket)
            Log.d(TAG, "SSDP M-SEARCH sent for Roku")

            val buffer = ByteArray(2048)
            val startTime = System.currentTimeMillis()
            val seen = mutableSetOf<String>()

            while (scanning && System.currentTimeMillis() - startTime < LISTEN_WINDOW_MS) {
                try {
                    val receivePacket = DatagramPacket(buffer, buffer.size)
                    socket.receive(receivePacket)

                    val response = String(receivePacket.data, 0, receivePacket.length, StandardCharsets.UTF_8)
                    if (response.contains(ROKU_ST, ignoreCase = true) || response.contains("roku", ignoreCase = true)) {
                        val location = parseLocationHeader(response)
                            ?: "http://${receivePacket.address.hostAddress}:$DEFAULT_ROKU_PORT/"

                        val ip = try { URI(location).host } catch (_: Exception) { receivePacket.address.hostAddress }
                            ?: continue
                        if (ip in seen) continue
                        seen.add(ip)

                        val deviceInfo = queryDeviceInfo(ip, location)
                        if (deviceInfo != null) {
                            val target = RokuCastTarget(deviceInfo, context)
                            deviceDiscovery.addDevice(target)
                            Log.d(TAG, "Roku found: ${deviceInfo.friendlyName} @ ${deviceInfo.ip}")
                        }
                    }
                } catch (_: java.net.SocketTimeoutException) {
                    // Expected per iteration
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Roku SSDP error: ${e.message}")
        } finally {
            socket?.close()
        }
    }

    /** Query device-info to get the friendly name. */
    private fun queryDeviceInfo(ip: String, location: String): RokuDeviceInfo? {
        return try {
            val port = try { URI(location).port.takeIf { it > 0 } } catch (_: Exception) { null } ?: DEFAULT_ROKU_PORT
            val url = URL("http://$ip:$port/query/device-info")
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 3_000
            conn.readTimeout = 3_000
            conn.requestMethod = "GET"
            val code = conn.responseCode
            if (code != 200) {
                conn.disconnect()
                return RokuDeviceInfo(ip, port, location, "Roku ($ip)")
            }
            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(conn.inputStream)
            conn.disconnect()
            val friendlyName = doc.getElementsByTagName("friendly-device-name")
                ?.item(0)?.textContent?.takeIf { it.isNotBlank() }
                ?: doc.getElementsByTagName("user-device-name")?.item(0)?.textContent?.takeIf { it.isNotBlank() }
                ?: doc.getElementsByTagName("model-name")?.item(0)?.textContent?.takeIf { it.isNotBlank() }
                ?: "Roku ($ip)"
            RokuDeviceInfo(ip, port, location, friendlyName)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to query Roku device info at $ip: ${e.message}")
            null
        }
    }

    private fun parseLocationHeader(response: String): String? {
        for (line in response.split("\r\n", "\n")) {
            if (line.startsWith("LOCATION:", ignoreCase = true)) {
                return line.substring("LOCATION:".length).trim().takeIf { it.isNotBlank() }
            }
        }
        return null
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        multicastLock = wifiManager.createMulticastLock("CastLite-Roku").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        try { if (multicastLock?.isHeld == true) multicastLock?.release() } catch (_: Exception) {}
        multicastLock = null
    }

    companion object {
        private const val TAG = "RokuDiscovery"
        private const val SSDP_ADDRESS = "239.255.255.250"
        private const val SSDP_PORT = 1900
        private const val ROKU_ST = "roku:ecp"
        private const val MX_SECONDS = 3
        private const val SOCKET_TIMEOUT_MS = 3_000
        private const val LISTEN_WINDOW_MS = 5_000L
        private const val DEFAULT_ROKU_PORT = 8060
    }
}
