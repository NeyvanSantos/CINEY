package com.example.castlite.casting.dlna

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.example.castlite.casting.DeviceDiscovery
import com.example.castlite.casting.DiscoveryLifecycle
import com.example.castlite.casting.CastProtocol
import org.jupnp.UpnpServiceImpl
import org.jupnp.DefaultUpnpServiceConfiguration
import org.jupnp.model.message.header.UDADeviceTypeHeader
import org.jupnp.model.meta.RemoteDevice
import org.jupnp.model.types.UDADeviceType
import org.jupnp.registry.DefaultRegistryListener
import org.jupnp.registry.Registry
import kotlin.concurrent.thread

/**
 * Discovers DLNA Media Renderers on the local network using jUPnP.
 * Uses UpnpServiceImpl directly (no Android service binding required).
 * Each discovered renderer is exposed as a [DlnaCastTarget] and added to [DeviceDiscovery].
 */
class DlnaDiscovery(
    private val context: Context,
    private val deviceDiscovery: DeviceDiscovery
) {
    @Volatile private var upnpService: UpnpServiceImpl? = null
    private val lifecycle = DiscoveryLifecycle()
    private var multicastLock: WifiManager.MulticastLock? = null

    private val registryListener = object : DefaultRegistryListener() {
        override fun remoteDeviceAdded(registry: Registry, device: RemoteDevice) {
            if (registry === upnpService?.registry && isMediaRenderer(device)) {
                Log.d(TAG, "DLNA renderer found: ${device.details.friendlyName}")
                val target = DlnaCastTarget(device, upnpService?.controlPoint, context)
                deviceDiscovery.addDevice(target)
            }
        }

        override fun remoteDeviceRemoved(registry: Registry, device: RemoteDevice) {
            if (registry === upnpService?.registry && isMediaRenderer(device)) {
                Log.d(TAG, "DLNA renderer lost: ${device.details.friendlyName}")
                val toRemove = deviceDiscovery.allDevices.filterIsInstance<DlnaCastTarget>()
                    .firstOrNull { it.deviceUdn == device.identity.udn.identifierString }
                if (toRemove != null) { toRemove.disconnect(); deviceDiscovery.removeDevice(toRemove) }
            }
        }
    }

    /** Start discovering DLNA renderers. Call from main thread. */
    fun start() {
        val generation = synchronized(lifecycle) {
            val next = lifecycle.begin()
            if (next != null) acquireMulticastLock()
            next
        } ?: run { refresh(); return }
        thread(name = "CastLite-DLNA-init", isDaemon = true) {
            var service: UpnpServiceImpl? = null
            try {
                // Passa false para ignorar o check de ambiente Android que dispara java.lang.Error
                val config = object : DefaultUpnpServiceConfiguration(false) {}
                val created = UpnpServiceImpl(config)
                service = created
                created.startup()
                val published = synchronized(lifecycle) {
                    if (!lifecycle.isCurrent(generation)) false else {
                        upnpService = created
                        created.registry?.addListener(registryListener)
                        created.controlPoint?.search(UDADeviceTypeHeader(MEDIA_RENDERER_TYPE), SEARCH_TIMEOUT_SECONDS)
                        true
                    }
                }
                if (!published) { created.shutdown(); return@thread }
                Log.d(TAG, "DLNA discovery started")
            } catch (t: Throwable) {
                runCatching { service?.shutdown() }
                synchronized(lifecycle) {
                    if (lifecycle.isCurrent(generation)) {
                        lifecycle.stop(); upnpService = null; releaseMulticastLock()
                    }
                }
                Log.w(TAG, "DLNA discovery failed: ${t.javaClass.simpleName}")
            }
        }
    }

    /** Stop discovery and release resources. */
    fun stop() {
        val service = synchronized(lifecycle) {
            lifecycle.stop()
            val current = upnpService
            upnpService = null
            releaseMulticastLock()
            current
        }
        deviceDiscovery.allDevices.filterIsInstance<DlnaCastTarget>().forEach { it.disconnect() }
        deviceDiscovery.removeByProtocol(CastProtocol.DLNA)
        if (service != null) thread(name = "CastLite-DLNA-stop", isDaemon = true) {
            runCatching { service.registry?.removeListener(registryListener); service.shutdown() }
                .onFailure { Log.w(TAG, "DLNA cleanup failed: ${it.javaClass.simpleName}") }
        }
    }

    /** Trigger a new search for renderers. */
    fun refresh() {
        upnpService?.controlPoint?.search(UDADeviceTypeHeader(MEDIA_RENDERER_TYPE), SEARCH_TIMEOUT_SECONDS)
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return
        multicastLock = wifiManager.createMulticastLock("CastLite-DLNA").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        try { if (multicastLock?.isHeld == true) multicastLock?.release() } catch (_: Exception) {}
        multicastLock = null
    }

    companion object {
        private const val TAG = "DlnaDiscovery"
        private const val SEARCH_TIMEOUT_SECONDS = 5
        private val MEDIA_RENDERER_TYPE = UDADeviceType("MediaRenderer")

        fun isMediaRenderer(device: RemoteDevice): Boolean {
            return device.type.type.equals("MediaRenderer", ignoreCase = true)
        }
    }
}
