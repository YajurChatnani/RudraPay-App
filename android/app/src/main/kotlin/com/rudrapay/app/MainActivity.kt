package com.rudrapay.app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
	private val channelName = "com.rudrapay.app/classic_bt"
	private val eventChannelName = "com.rudrapay.app/classic_bt_stream"
	private val executor = Executors.newCachedThreadPool()
	private val socketHandles = ConcurrentHashMap<Int, BluetoothSocket>()
	private val readerFutures = ConcurrentHashMap<Int, java.util.concurrent.Future<*>>()
	private var serverSocket: BluetoothServerSocket? = null
	private val handleCounter = AtomicInteger(1)
	@Volatile private var eventSink: EventChannel.EventSink? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"startServer" -> handleStartServer(call.arguments, result)
				"connect" -> handleConnect(call.arguments, result)
				"closeServer" -> handleCloseServer(result)
				"closeConnection" -> handleCloseConnection(call.arguments, result)
				"sendBytes" -> handleSendBytes(call.arguments, result)
				else -> result.notImplemented()
			}
		}

		EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(object : EventChannel.StreamHandler {
			override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
				eventSink = events
			}

			override fun onCancel(arguments: Any?) {
				eventSink = null
			}
		})
	}

	private fun handleStartServer(arguments: Any?, result: MethodChannel.Result) {
		val args = arguments as? Map<*, *>
		val uuidStr = args?.get("uuid") as? String ?: return result.error("ARG", "uuid missing", null)
		val serviceName = (args?.get("serviceName") as? String) ?: "RudraPay"
		val timeoutSec = (args?.get("timeoutSec") as? Int) ?: 300

		val adapter = BluetoothAdapter.getDefaultAdapter() ?: return result.error("BT", "Bluetooth adapter unavailable", null)

		// Cancel discovery to speed up accept
		try { adapter.cancelDiscovery() } catch (_: SecurityException) {}

		// Request discoverable (non-blocking prompt)
		try {
			val discoverableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
				putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, timeoutSec)
			}
			startActivity(discoverableIntent)
		} catch (e: Exception) {
			Log.w("CBT", "Discoverable request failed: $e")
		}

		val uuid = UUID.fromString(uuidStr)
		executor.submit {
			try {
				serverSocket = adapter.listenUsingRfcommWithServiceRecord(serviceName, uuid)
				Log.i("CBT", "Server socket created, awaiting connection...")

				val timeoutMs = timeoutSec * 1000
				val socket = serverSocket!!.accept(timeoutMs)
				val handle = handleCounter.getAndIncrement()
				socketHandles[handle] = socket

				startReader(handle, socket)

				val remote = socket.remoteDevice
				runOnUiThread {
					result.success(mapOf(
						"handle" to handle,
						"address" to remote.address,
						"name" to remote.name
					))
				}
			} catch (e: IOException) {
				Log.e("CBT", "Server accept failed", e)
				runOnUiThread { result.error("ACCEPT", "Server accept failed: ${e.message}", null) }
			} finally {
				try { serverSocket?.close() } catch (_: IOException) {}
				serverSocket = null
			}
		}
	}

	private fun handleConnect(arguments: Any?, result: MethodChannel.Result) {
		val args = arguments as? Map<*, *>
		val uuidStr = args?.get("uuid") as? String ?: return result.error("ARG", "uuid missing", null)
		val address = args["address"] as? String ?: return result.error("ARG", "address missing", null)
		val timeoutSec = (args["timeoutSec"] as? Int) ?: 15

		val adapter = BluetoothAdapter.getDefaultAdapter() ?: return result.error("BT", "Bluetooth adapter unavailable", null)
		try { adapter.cancelDiscovery() } catch (_: SecurityException) {}

		val uuid = UUID.fromString(uuidStr)

		executor.submit {
			try {
				val device = adapter.getRemoteDevice(address)
				val socket = device.createRfcommSocketToServiceRecord(uuid)

				// Connect with timeout
				val future = executor.submit { socket.connect() }
				future.get(timeoutSec.toLong(), TimeUnit.SECONDS)

				val handle = handleCounter.getAndIncrement()
				socketHandles[handle] = socket
				startReader(handle, socket)
				runOnUiThread {
					result.success(mapOf(
						"handle" to handle,
						"address" to address,
						"name" to device.name
					))
				}
			} catch (e: Exception) {
				Log.e("CBT", "Client connect failed", e)
				runOnUiThread { result.error("CONNECT", "Connection failed: ${e.message}", null) }
			}
		}
	}

	private fun handleCloseServer(result: MethodChannel.Result) {
		try { serverSocket?.close() } catch (_: IOException) {}
		serverSocket = null
		result.success(true)
	}

	private fun handleCloseConnection(arguments: Any?, result: MethodChannel.Result) {
		val args = arguments as? Map<*, *>
		val handle = args?.get("handle") as? Int ?: return result.error("ARG", "handle missing", null)
		val socket = socketHandles.remove(handle)
		readerFutures.remove(handle)?.cancel(true)
		try { socket?.close() } catch (_: IOException) {}
		result.success(true)
	}

	private fun handleSendBytes(arguments: Any?, result: MethodChannel.Result) {
		val args = arguments as? Map<*, *>
		val handle = args?.get("handle") as? Int ?: return result.error("ARG", "handle missing", null)
		val data = args["data"] as? ByteArray ?: return result.error("ARG", "data missing", null)
		val socket = socketHandles[handle] ?: return result.error("SOCKET", "socket not found", null)

		try {
			socket.outputStream.write(data)
			socket.outputStream.flush()
			result.success(true)
		} catch (e: IOException) {
			Log.e("CBT", "sendBytes failed", e)
			result.error("SEND", "Failed to send: ${e.message}", null)
		}
	}

	private fun startReader(handle: Int, socket: BluetoothSocket) {
		val future = executor.submit {
			try {
				val buffer = ByteArray(1024)
				val input = socket.inputStream
				while (!Thread.currentThread().isInterrupted) {
					val read = input.read(buffer)
					if (read <= 0) break
					val data = buffer.copyOf(read)
					runOnUiThread {
						eventSink?.success(mapOf(
							"handle" to handle,
							"data" to data
						))
					}
				}
			} catch (e: IOException) {
				Log.w("CBT", "Reader ended for handle=$handle: ${e.message}")
				runOnUiThread {
					eventSink?.error("READ", "Read failed: ${e.message}", null)
				}
			} finally {
				try { socket.close() } catch (_: IOException) {}
				socketHandles.remove(handle)
			}
		}
		readerFutures[handle] = future
	}
}
