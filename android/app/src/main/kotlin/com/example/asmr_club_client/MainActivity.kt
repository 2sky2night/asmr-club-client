package com.example.asmr_club_client

import android.content.Intent
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.asmr_club_client/path_resolver"
    private val PICK_DIR_REQUEST_CODE = 1001
    private var resultCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "selectDirectory") {
                resultCallback = result
                openDirectoryPicker()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openDirectoryPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        startActivityForResult(intent, PICK_DIR_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_DIR_REQUEST_CODE && resultCode == RESULT_OK && data != null) {
            val uri: Uri? = data.data
            val path = resolveRealPath(uri)
            resultCallback?.success(path)
            resultCallback = null
        } else {
            resultCallback?.success(null)
            resultCallback = null
        }
    }

    private fun resolveRealPath(uri: Uri?): String? {
        if (uri == null) return null
        
        // 尝试从 URI 中提取路径
        val uriPath = uri.path ?: return null
        
        // 处理 MuMu 模拟器常见的 content://com.android.externalstorage.documents/tree/...
        if (uriPath.contains("MuMuShared")) {
            // MuMu 模拟器通常映射到 /sdcard 或 /storage/emulated/0
            // 提取最后的文件夹名称
            val parts = uriPath.split(":")
            if (parts.size > 1) {
                val subPath = parts[1].replace("/tree/", "").replace("/document/", "")
                return File(Environment.getExternalStorageDirectory(), subPath).absolutePath
            }
        }
        
        // 标准 Android 路径解析
        if (uriPath.startsWith("/tree/primary:")) {
            val subPath = uriPath.replace("/tree/primary:", "")
            return File(Environment.getExternalStorageDirectory(), subPath).absolutePath
        }
        
        // 兜底：返回外部存储根目录
        return Environment.getExternalStorageDirectory().absolutePath
    }
}
