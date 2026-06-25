package com.example.bili_novel_packer

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerSafChannel(flutterEngine)
    }

    private fun registerSafChannel(engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "bilinovel/saf")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initBilinovelDir" -> result.success(initDir())
                "saveToBilinovel" -> {
                    val fileName = call.argument<String>("fileName") ?: ""
                    val data = call.argument<ByteArray>("data") ?: byteArrayOf()
                    val subfolder = call.argument<String>("subfolder") ?: ""
                    result.success(saveFile(fileName, data, subfolder))
                }
                "openFile" -> {
                    val uri = call.argument<String>("uri") ?: ""
                    openFile(uri)
                    result.success(null)
                }
                "shareFile" -> {
                    val uri = call.argument<String>("uri") ?: ""
                    shareFile(uri)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initDir(): String {
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, ".bilinovel")
            put(MediaStore.Downloads.MIME_TYPE, "text/plain")
            put(MediaStore.Downloads.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/bilinovel")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        try {
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            uri?.let {
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(it, values, null, null)
                contentResolver.delete(it, null, null)
            }
        } catch (_: Exception) {}
        return "${Environment.DIRECTORY_DOWNLOADS}/bilinovel"
    }

    private fun openFile(uri: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "选择阅读器打开"))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun shareFile(uri: String) {
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/epub+zip"
                putExtra(Intent.EXTRA_STREAM, Uri.parse(uri))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "分享 EPUB"))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun saveFile(fileName: String, data: ByteArray, subfolder: String = ""): String {
        val path = if (subfolder.isNotEmpty()) {
            "${Environment.DIRECTORY_DOWNLOADS}/bilinovel/$subfolder"
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/bilinovel"
        }
        return try {
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/epub+zip")
                put(MediaStore.Downloads.RELATIVE_PATH, path)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues) ?: return ""
            contentResolver.openOutputStream(uri)?.use { it.write(data) }
            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, contentValues, null, null)
            uri.toString()
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        }
    }
}
