package com.rudrapay.app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.os.Handler
import android.os.Looper
import java.util.UUID

class BluetoothReceiverService {
    companion object {
        // Standard SPP UUID for Bluetooth Serial Communication
        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private const val SERVICE_NAME = "RudraPay"
    }

    private var serverSocket: BluetoothServerSocket? = null
    private var bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var listeningThread: Thread? = null
    private var onConnectionAccepted: ((BluetoothSocket) -> Unit)? = null
    private val handler = Handler(Looper.getMainLooper())

    fun startListening(onConnectionAccepted: (BluetoothSocket) -> Unit): Boolean {
        return try {
            // Stop any existing listener
            stopListening()

            this.onConnectionAccepted = onConnectionAccepted

            // Create server socket
            serverSocket = bluetoothAdapter?.listenUsingRfcommWithServiceRecord(
                SERVICE_NAME,
                SPP_UUID
            )

            if (serverSocket != null) {
                // Start listening in a background thread
                listeningThread = Thread {
                    try {
                        android.util.Log.d("BluetoothReceiver", "Server socket listening for SPP UUID $SPP_UUID")
                        while (true) {
                            android.util.Log.d("BluetoothReceiver", "Waiting for connection...")
                            val socket: BluetoothSocket = serverSocket!!.accept()
                            android.util.Log.d("BluetoothReceiver", "Connection accepted from ${socket.remoteDevice?.name} (${socket.remoteDevice?.address})")
                            
                            // Call the handler on main thread
                            handler.post {
                                onConnectionAccepted?.invoke(socket)
                            }
                        }
                    } catch (e: Exception) {
                        if (serverSocket != null) {
                            android.util.Log.e("BluetoothReceiver", "Error in accept loop: ${e.message}")
                        }
                    }
                }
                listeningThread?.isDaemon = true
                listeningThread?.start()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("BluetoothReceiver", "Failed to start listening: ${e.message}")
            false
        }
    }

    fun stopListening() {
        try {
            serverSocket?.close()
            serverSocket = null
            listeningThread?.interrupt()
            listeningThread = null
        } catch (e: Exception) {
            android.util.Log.e("BluetoothReceiver", "Error stopping listener: ${e.message}")
        }
    }
}
