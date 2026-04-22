package com.example.asmr_club_client

import android.content.Intent
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import androidx.documentfile.provider.DocumentFile
import android.content.ContentUris

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.asmr_club_client/path_resolver"
    private val PICK_DIR_REQUEST_CODE = 1001
    private var resultCallback: MethodChannel.Result? = null
    private var savedDirUri: Uri? = null // 保存用户选择的目录 URI

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "selectDirectory" -> {
                    resultCallback = result
                    openDirectoryPicker()
                }
                "listFilesNative" -> {
                    val path = call.argument<String>("path")
                    result.success(listFilesNative(path))
                }
                "readEntryJsonNative" -> {
                    val path = call.argument<String>("path")
                    result.success(readEntryJsonNative(path))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun listFilesNative(path: String?): List<Map<String, Any>> {
        android.util.Log.d("NativeDebug", "收到列出目录请求: $path")
        val resultList = mutableListOf<Map<String, Any>>()
        
        // 尝试使用 DocumentFile (SAF) 方式，这能绕过 Linux 权限位限制
        if (savedDirUri != null && path != null) {
            try {
                val parentDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
                // 计算相对路径
                val rootPath = resolveRealPath(savedDirUri!!)
                if (rootPath != null && path.startsWith(rootPath)) {
                    val relativePath = path.substring(rootPath.length).trim('/')
                    var currentDoc = parentDoc
                    if (relativePath.isNotEmpty()) {
                        for (part in relativePath.split('/')) {
                            currentDoc = currentDoc?.findFile(part)
                        }
                    }
                    
                    if (currentDoc != null && currentDoc.isDirectory) {
                        android.util.Log.d("NativeDebug", "使用 DocumentFile 成功定位目录")
                        currentDoc.listFiles().forEach { doc ->
                            android.util.Log.d("NativeDebug", "DocumentFile 发现: ${doc.name} (文件夹: ${doc.isDirectory})")
                            resultList.add(mapOf(
                                "name" to (doc.name ?: "unknown"),
                                "path" to path + "/" + doc.name,
                                "isDirectory" to doc.isDirectory
                            ))
                        }
                        return resultList
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("NativeDebug", "DocumentFile 方式失败", e)
            }
        }

        // 兜底：使用传统 File 方式
        if (path.isNullOrEmpty()) return resultList
        try {
            val dir = File(path)
            android.util.Log.d("NativeDebug", "目录存在: ${dir.exists()}, 是文件夹: ${dir.isDirectory}")
            if (dir.exists() && dir.isDirectory) {
                val files = dir.listFiles()
                android.util.Log.d("NativeDebug", "找到 ${files?.size ?: 0} 个项目")
                files?.forEach { file ->
                    android.util.Log.d("NativeDebug", "发现项目: ${file.name} (文件夹: ${file.isDirectory})")
                    resultList.add(mapOf(
                        "name" to file.name,
                        "path" to file.absolutePath,
                        "isDirectory" to file.isDirectory
                    ))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("NativeDebug", "列出目录失败", e)
            e.printStackTrace()
        }
        return resultList
    }

    private fun readEntryJsonNative(path: String?): String? {
        android.util.Log.d("NativeDebug", "尝试读取文件: $path")
        if (path.isNullOrEmpty()) return null
        
        // 优先使用 DocumentFile (SAF) 读取，绕过 Linux 权限限制
        if (savedDirUri != null) {
            try {
                val rootPath = resolveRealPath(savedDirUri!!)
                if (rootPath != null && path.startsWith(rootPath)) {
                    val relativePath = path.substring(rootPath.length).trim('/')
                    var currentDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
                    
                    for (part in relativePath.split('/')) {
                        currentDoc = currentDoc?.findFile(part)
                    }
                    
                    if (currentDoc != null && currentDoc.canRead()) {
                        val inputStream = contentResolver.openInputStream(currentDoc.uri)
                        val content = inputStream?.bufferedReader()?.use { it.readText() }
                        inputStream?.close()
                        android.util.Log.d("NativeDebug", "DocumentFile 读取成功, 长度: ${content?.length}")
                        return content
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("NativeDebug", "DocumentFile 读取失败", e)
            }
        }

        // 兜底：传统 File 方式
        try {
            val file = File(path)
            if (file.exists() && file.canRead()) {
                return file.readText()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
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
            savedDirUri = uri // 保存 URI 供后续使用
            contentResolver.takePersistableUriPermission(uri!!, Intent.FLAG_GRANT_READ_URI_PERMISSION)
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
