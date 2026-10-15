package com.example.castlite.casting.dlna

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import com.example.castlite.casting.DeviceDiscovery
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
    private var upnpService: UpnpServiceImpl? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    private val registryListener = object : DefaultRegistryListener() {
        override fun remoteDeviceAdded(registry: Registry, device: RemoteDevice) {
            if (isMediaRenderer(device)) {
                Log.d(TAG, "DLNA renderer found: ${device.details.friendlyName}")
                val target = DlnaCastTarget(device, upnpService?.controlPoint, context)
                deviceDiscovery.addDevice(target)
            }
        }

        override fun remoteDeviceRemoved(registry: Registry, device: RemoteDevice) {
            if (isMediaRenderer(device)) {
                Log.d(TAG, "DLNA renderer lost: ${device.details.friendlyName}")
                val toRemove = deviceDiscovery.allDevices.filterIsInstance<DlnaCastTarget>()
                    .firstOrNull { it.deviceUdn == device.identity.udn.identifierString }
                if (toRemove != null) deviceDiscovery.removeDevice(toRemove)
            }
        }
    }

    /** Start discovering DLNA renderers. Call from main thread. */
    fun start() {
        acquireMulticastLock()
        thread(name = "CastLite-DLNA-init", isDaemon = true) {
            try {
                // Passa false para ignorar o check de ambiente Android que dispara java.lang.Error
                val config = object : DefaultUpnpServiceConfiguration(false) {}
                val service = UpnpServiceImpl(config)
                service.startup()
                upnpService = service
                service.registry?.addListener(registryListener)
                service.controlPoint?.search(UDADeviceTypeHeader(MEDIA_RENDERER_TYPE), SEARCH_TIMEOUT_SECONDS)
                Log.d(TAG, "DLNA discovery started")
            } catch (t: Throwable) {
                Log.e(TAG, "DLNA discovery failed to start: ${t.message}", t)
            }
        }
    }

    /** Stop discovery and release resources. */
    fun stop() {
        try {
            upnpService?.registry?.removeListener(registryListener)
            upnpService?.shutdown()
        } catch (_: Exception) {}
        upnpService = null
        releaseMulticastLock()
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
