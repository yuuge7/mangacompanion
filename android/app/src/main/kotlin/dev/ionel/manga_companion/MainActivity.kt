package dev.ionel.manga_companion

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveFile") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error("busy", "A save dialog is already open", null)
            return
        }
        val fileName = call.argument<String>("fileName")
        val content = call.argument<String>("content")
        if (fileName == null || content == null) {
            result.error("bad_args", "fileName and content are required", null)
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mimeType") ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, fileName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, downloadsUri())
            }
        }

        pendingResult = result
        pendingContent = content
        try {
            startActivityForResult(intent, CREATE_DOCUMENT_REQUEST)
        } catch (e: Exception) {
            pendingResult = null
            pendingContent = null
            result.error("no_picker", "This device has no file picker available", null)
        }
    }

    /** Makes the picker open on Downloads rather than wherever it was left last. */
    private fun downloadsUri(): Uri = DocumentsContract.buildDocumentUri(
        EXTERNAL_STORAGE_AUTHORITY,
        "primary:${Environment.DIRECTORY_DOWNLOADS}",
    )

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != CREATE_DOCUMENT_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult ?: return
        val content = pendingContent.orEmpty()
        pendingResult = null
        pendingContent = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // picker dismissed, nothing to report
            return
        }
        try {
            // "wt" truncates, so picking an existing file overwrites it cleanly.
            contentResolver.openOutputStream(uri, "wt").use { stream ->
                requireNotNull(stream) { "Could not open the chosen file for writing" }
                stream.write(content.toByteArray(Charsets.UTF_8))
            }
            result.success(displayName(uri) ?: uri.lastPathSegment)
        } catch (e: Exception) {
            result.error("write_failed", e.message, null)
        }
    }

    private fun displayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
            }

    companion object {
        private const val CHANNEL = "dev.ionel.manga_companion/export"
        private const val CREATE_DOCUMENT_REQUEST = 0x4A53
        private const val EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents"
    }
}
