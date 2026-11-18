package com.naveen.noxsnap.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import com.naveen.noxsnap.network.DiscoveredMac
import com.naveen.noxsnap.network.NoxSnapClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.net.Inet4Address
import java.net.NetworkInterface

class NoxSnapDiscovery(
    private val context: Context,
    private val onMacFound: (DiscoveredMac) -> Unit
) {
    private val tag = "NoxSnapDiscovery"
    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val client = NoxSnapClient()
    private val scope = CoroutineScope(Dispatchers.IO)
    private val prefs = context.getSharedPreferences("noxsnap_discovery_prefs", Context.MODE_PRIVATE)

    private val serviceTypes = listOf("_noxsnap._tcp", "_noxdock._tcp")
    private val discoveryListeners = mutableListOf<NsdManager.DiscoveryListener>()
    
    @Volatile
    private var isConnected = false

    companion object {
        const val KEY_LAST_MAC_HOST = "last_mac_host"
        const val KEY_LAST_MAC_NAME = "last_mac_name"
        
        @Volatile
        var cachedMac: DiscoveredMac? = null
        
        fun getCachedMac(context: Context): DiscoveredMac? {
            if (cachedMac != null) return cachedMac
            val prefs = context.getSharedPreferences("noxsnap_discovery_prefs", Context.MODE_PRIVATE)
            val host = prefs.getString(KEY_LAST_MAC_HOST, null)
            val name = prefs.getString(KEY_LAST_MAC_NAME, "MacBook") ?: "MacBook"
            return if (!host.isNullOrEmpty()) {
                DiscoveredMac(name, host, 53320).also { cachedMac = it }
            } else null
        }
    }

    fun startDiscovery() {
        isConnected = false

        // 1. Instant check: Fast re-connect to last known Mac host
        scope.launch {
            val lastHost = prefs.getString(KEY_LAST_MAC_HOST, null)
            val lastName = prefs.getString(KEY_LAST_MAC_NAME, "MacBook") ?: "MacBook"
            if (!lastHost.isNullOrEmpty()) {
                val json = client.checkStatus(lastHost, 53320)
                if (json != null) {
                    val name = json.optString("deviceName", lastName)
                    handleMacFound(name, lastHost, 53320)
                    return@launch
                }
            }

            // 2. Immediate ARP table scan (instant detection on Mobile Hotspot & Wi-Fi)
            probeArpTable()

            // 3. Parallel subnet probe across all active network interfaces
            probeAllSubnets()
        }

        // 4. Standard mDNS / DNS-SD discovery
        for (sType in serviceTypes) {
            val listener = object : NsdManager.DiscoveryListener {
                override fun onDiscoveryStarted(regType: String?) {
                    Log.d(tag, "NSD Discovery started for $regType")
                }

                override fun onServiceFound(serviceInfo: NsdServiceInfo?) {
                    if (serviceInfo == null || isConnected) return
                    Log.d(tag, "NSD service candidate: ${serviceInfo.serviceName}")
                    try {
                        nsdManager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                            override fun onResolveFailed(serviceInfo: NsdServiceInfo?, errorCode: Int) {
                                Log.w(tag, "Resolve failed: $errorCode")
                            }

                            override fun onServiceResolved(info: NsdServiceInfo?) {
                                if (info == null) return
                                val host = info.host?.hostAddress ?: return
                                val port = info.port
                                val name = info.serviceName ?: "MacBook"
                                handleMacFound(name, host, port)
                            }
                        })
                    } catch (e: Exception) {
                        Log.e(tag, "Error resolving: ${e.message}")
                    }
                }

                override fun onServiceLost(serviceInfo: NsdServiceInfo?) {}
                override fun onDiscoveryStopped(serviceType: String?) {}
                override fun onStartDiscoveryFailed(serviceType: String?, errorCode: Int) {}
                override fun onStopDiscoveryFailed(serviceType: String?, errorCode: Int) {}
            }

            try {
                nsdManager.discoverServices(sType, NsdManager.PROTOCOL_DNS_SD, listener)
                discoveryListeners.add(listener)
            } catch (e: Exception) {
                Log.e(tag, "Error starting discovery for $sType: ${e.message}")
            }
        }
    }

    private fun handleMacFound(name: String, host: String, port: Int) {
        if (isConnected) return
        isConnected = true
        Log.i(tag, "✅ Connected to Mac: $name at $host:$port")
        val mac = DiscoveredMac(name, host, port)
        cachedMac = mac
        prefs.edit()
            .putString(KEY_LAST_MAC_HOST, host)
            .putString(KEY_LAST_MAC_NAME, name)
            .apply()

        onMacFound(mac)
    }

    private suspend fun probeArpTable() {
        try {
            val arpCandidates = mutableListOf<String>()
            val arpFile = File("/proc/net/arp")
            if (arpFile.exists()) {
                BufferedReader(FileReader(arpFile)).use { reader ->
                    var line: String? = reader.readLine() // skip header
                    while (reader.readLine().also { line = it } != null) {
                        val parts = line!!.split("\\s+".toRegex())
                        if (parts.size >= 4) {
                            val ip = parts[0]
                            val flags = parts[2]
                            // 0x2 = complete/active ARP entry
                            if (flags == "0x2" && ip.contains(".")) {
                                arpCandidates.add(ip)
                            }
                        }
                    }
                }
            }

            for (ip in arpCandidates) {
                if (isConnected) break
                val json = client.checkStatus(ip, 53320)
                if (json != null) {
                    val name = json.optString("deviceName", "MacBook")
                    handleMacFound(name, ip, 53320)
                    return
                }
            }
        } catch (e: Exception) {
            Log.w(tag, "ARP probe error: ${e.message}")
        }
    }

    private suspend fun probeAllSubnets() {
        try {
            val activePrefixes = mutableSetOf<String>()
            val interfaces = NetworkInterface.getNetworkInterfaces() ?: return

            for (nif in interfaces) {
                if (nif.isLoopback || !nif.isUp) continue
                for (addr in nif.inetAddresses) {
                    if (addr is Inet4Address && !addr.isLoopbackAddress) {
                        val ip = addr.hostAddress ?: continue
                        val prefix = ip.substringBeforeLast(".")
                        activePrefixes.add(prefix)
                    }
                }
            }

            for (prefix in activePrefixes) {
                if (isConnected) break
                
                // Prioritize common host targets (.1, .25, .2, .100, .10, .50)
                val priorityTargets = listOf(
                    "$prefix.25", "$prefix.1", "$prefix.2", "$prefix.100", "$prefix.10", "$prefix.50", "$prefix.20"
                )

                for (target in priorityTargets) {
                    if (isConnected) break
                    val json = client.checkStatus(target, 53320)
                    if (json != null) {
                        val name = json.optString("deviceName", "MacBook")
                        handleMacFound(name, target, 53320)
                        return
                    }
                }

                // Fan out to remaining range (2..254) in batches of 16 coroutines
                val remainingTargets = (2..120).map { "$prefix.$it" }.filter { it !in priorityTargets }
                remainingTargets.chunked(16).forEach { batch ->
                    if (isConnected) return
                    val deferreds = batch.map { target ->
                        scope.async {
                            client.checkStatus(target, 53320)?.let { json ->
                                val name = json.optString("deviceName", "MacBook")
                                Pair(name, target)
                            }
                        }
                    }
                    val results = deferreds.awaitAll()
                    for (res in results) {
                        if (res != null) {
                            handleMacFound(res.first, res.second, 53320)
                            return
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(tag, "Subnet probe error: ${e.message}")
        }
    }

    fun stopDiscovery() {
        for (listener in discoveryListeners) {
            try {
                nsdManager.stopServiceDiscovery(listener)
            } catch (e: Exception) {}
        }
        discoveryListeners.clear()
    }
}
