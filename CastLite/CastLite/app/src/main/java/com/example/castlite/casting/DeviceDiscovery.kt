package com.example.castlite.casting

import java.util.concurrent.CopyOnWriteArrayList

/**
 * Central aggregator that collects devices from all protocol-specific
 * discovery sources (Google Cast, DLNA, Roku) and presents a unified list.
 */
class DeviceDiscovery {

    /** Listener notified whenever the aggregated device list changes. */
    fun interface OnDevicesChangedListener {
        fun onDevicesChanged(devices: List<CastTarget>)
    }

    private val devices = CopyOnWriteArrayList<CastTarget>()
    private val changeListeners = CopyOnWriteArrayList<OnDevicesChangedListener>()

    val allDevices: List<CastTarget> get() = devices.toList()

    fun addDevice(target: CastTarget) {
        if (devices.none { it.name == target.name && it.protocol == target.protocol }) {
            devices.add(target)
            notifyChanged()
        }
    }

    fun removeDevice(target: CastTarget) {
        if (devices.removeIf { it.name == target.name && it.protocol == target.protocol }) {
            notifyChanged()
        }
    }

    fun removeByProtocol(protocol: CastProtocol) {
        if (devices.removeIf { it.protocol == protocol }) {
            notifyChanged()
        }
    }

    fun clear() {
        devices.clear()
        notifyChanged()
    }

    fun addOnDevicesChangedListener(listener: OnDevicesChangedListener) {
        changeListeners.add(listener)
    }

    fun removeOnDevicesChangedListener(listener: OnDevicesChangedListener) {
        changeListeners.remove(listener)
    }

    private fun notifyChanged() {
        val snapshot = devices.toList()
        changeListeners.forEach { it.onDevicesChanged(snapshot) }
    }
}
