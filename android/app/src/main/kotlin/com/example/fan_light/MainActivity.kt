package com.example.fan_light

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.fan_light/mdns"
    private var nsdManager: NsdManager? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "discoverESP32") {
                discoverESP32(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun discoverESP32(result: MethodChannel.Result) {
        nsdManager = getSystemService(Context.NSD_SERVICE) as NsdManager
        val serviceType = "_http._tcp."

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {
                Log.d("MDNS", "🔍 Discovery started for $regType")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d("MDNS", "🛰 Service found: ${serviceInfo.serviceName}")

                nsdManager?.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onServiceResolved(resolvedInfo: NsdServiceInfo) {
                        val hostAddress = resolvedInfo.host.hostAddress
                        val port = resolvedInfo.port
                        Log.d("MDNS", "✅ Resolved: ${resolvedInfo.serviceName} @ $hostAddress:$port")
                        result.success("$hostAddress:$port")
                        nsdManager?.stopServiceDiscovery(discoveryListener)
                    }

                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                        Log.e("MDNS", "❌ Resolve failed for ${serviceInfo.serviceName} with error $errorCode")
                    }
                })
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.w("MDNS", "⚠️ Service lost: ${serviceInfo.serviceName}")
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d("MDNS", "🛑 Discovery stopped")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e("MDNS", "❌ Discovery start failed: $errorCode")
                result.error("DISCOVERY_FAILED", "Start discovery failed", null)
                nsdManager?.stopServiceDiscovery(discoveryListener)
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e("MDNS", "❌ Stop discovery failed: $errorCode")
                result.error("STOP_DISCOVERY_FAILED", "Stop discovery failed", null)
                nsdManager?.stopServiceDiscovery(discoveryListener)
            }
        }

        nsdManager?.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    }
}
