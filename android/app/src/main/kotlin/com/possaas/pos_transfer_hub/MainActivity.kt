package com.possaas.pos_transfer_hub

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.content.pm.PackageManager
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileInputStream

/**
 * Small storage bridge:
 *  - saveToDownloads: moves a finished download from app-private storage into the
 *    public Downloads folder (MediaStore on Android 10+, plain file copy below).
 *  - openFile: opens a saved file with whichever app can handle it.
 */
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    /** Android 9 and below need WRITE_EXTERNAL_STORAGE to write into Downloads. */
    private fun ensureLegacyStorage(result: MethodChannel.Result) {
        val needed = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
        if (!needed || granted) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        ActivityCompat.requestPermissions(
            this, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 4711
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4711) {
            pendingPermission?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingPermission = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.possaas.transferhub/storage")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "ensureStoragePermission" -> ensureLegacyStorage(result)
                        "saveToDownloads" -> result.success(
                            saveToDownloads(
                                call.argument<String>("source")!!,
                                call.argument<String>("name")!!,
                                call.argument<String>("mime") ?: "application/octet-stream",
                            )
                        )
                        "openFile" -> {
                            openFile(
                                call.argument<String>("location")!!,
                                call.argument<String>("mime") ?: "*/*",
                            )
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("STORAGE_ERROR", e.message, null)
                }
            }
    }

    private fun saveToDownloads(source: String, name: String, mime: String): String {
        val src = File(source)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/TransferHub")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create file in Downloads")
            resolver.openOutputStream(uri)!!.use { out ->
                FileInputStream(src).use { it.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "TransferHub",
        )
        dir.mkdirs()
        var target = File(dir, name)
        var i = 1
        while (target.exists()) {
            val dot = name.lastIndexOf('.')
            target = if (dot > 0) File(dir, name.substring(0, dot) + " ($i)" + name.substring(dot))
            else File(dir, "$name ($i)")
            i++
        }
        src.copyTo(target)
        return target.absolutePath
    }

    private fun openFile(location: String, mime: String) {
        val uri: Uri = if (location.startsWith("content://")) {
            Uri.parse(location)
        } else {
            FileProvider.getUriForFile(this, "$packageName.fileprovider", File(location))
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
