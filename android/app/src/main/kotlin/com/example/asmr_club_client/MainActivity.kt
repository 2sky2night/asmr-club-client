package com.example.asmr_club_client

import android.content.Intent
import android.net.Uri
import android.os.Environment
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import androidx.documentfile.provider.DocumentFile
import org.json.JSONObject

class MainActivity : AudioServiceActivity() {
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
                "getPlayableUri" -> {
                    val path = call.argument<String>("path")
                    result.success(getPlayableUri(path))
                }
                "scanBilibiliCacheNative" -> {
                    val path = call.argument<String>("path")
                    // 【性能修复】在后台线程执行扫描，避免阻塞 Android 主线程导致 UI 卡死
                    Thread {
                        val resultList = scanBilibiliCacheNative(path)
                        runOnUiThread {
                            result.success(resultList)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scanBilibiliCacheNative(rootPath: String?): List<Map<String, Any>> {
        if (rootPath.isNullOrEmpty()) return emptyList()
        val resultList = mutableListOf<Map<String, Any>>()
        val processedPaths = mutableSetOf<String>()
        
        try {
            val rootFile = File(rootPath)
            if (rootFile.exists() && rootFile.isDirectory) {
                scanDirectoryRecursive(rootFile, rootPath, resultList, processedPaths, 0)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return resultList
    }

    private fun scanDirectoryRecursive(
        dir: File,
        rootPath: String,
        resultList: MutableList<Map<String, Any>>,
        processedPaths: MutableSet<String>,
        depth: Int
    ) {
        if (depth > 8) return
        
        val files = dir.listFiles() ?: return
        for (file in files) {
            if (file.isDirectory) {
                if (file.absolutePath.startsWith(rootPath) && !isSystemDirectory(file.absolutePath)) {
                    scanDirectoryRecursive(file, rootPath, resultList, processedPaths, depth + 1)
                }
            } else {
                val lowerName = file.name.lowercase()
                if (lowerName.endsWith(".mp3") || lowerName == "audio.m4s") {
                    processAudioFileWithMeta(file, resultList, processedPaths)
                }
            }
        }
    }

    private fun processAudioFileWithMeta(
        audioFile: File,
        resultList: MutableList<Map<String, Any>>,
        processedPaths: MutableSet<String>
    ) {
        val audioPath = audioFile.absolutePath
        if (processedPaths.contains(audioPath)) return

        var currentDir: File? = audioFile.parentFile
        var meta: Map<String, Any>? = null
        var bestAudioPath: String? = null

        // 1. 向上查找 entry.json (使用 SAF 读取以绕过权限限制)
        for (i in 0..2) {
            if (currentDir == null) break
            val entryFile = File(currentDir, "entry.json")
            if (entryFile.exists()) {
                val content = readEntryJsonViaSAF(entryFile.absolutePath)
                if (content != null && content.isNotEmpty()) {
                    try {
                        val json = JSONObject(content)
                        val title = json.optString("title")
                        val owner = json.optString("owner_name")
                        val cover = json.optString("cover")
                        
                        if (title.isNotEmpty()) {
                            meta = mapOf(
                                "title" to title,
                                "owner_name" to owner,
                                "cover" to cover
                            )
                            break
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
            currentDir = currentDir.parentFile
        }

        // 2. 确定音频路径（优先级：audio.m4s > mp3）
        if (audioFile.name.lowercase() == "audio.m4s") {
            bestAudioPath = audioPath
        } else if (audioFile.name.lowercase().endsWith(".mp3")) {
            val potentialM4s = File(audioFile.parentFile, "audio.m4s")
            if (!potentialM4s.exists()) {
                bestAudioPath = audioPath
            }
        }

        // 3. 添加到结果列表
        if (bestAudioPath != null && !processedPaths.contains(bestAudioPath)) {
            processedPaths.add(bestAudioPath)
            val musicMap = mutableMapOf<String, Any>(
                "path" to bestAudioPath,
                "title" to (meta?.get("title") ?: audioFile.nameWithoutExtension),
                "author" to (meta?.get("owner_name") ?: "本地音乐")
            )
            if (meta?.get("cover") is String && (meta["cover"] as String).isNotEmpty()) {
                musicMap["cover"] = meta["cover"] as String
            }
            resultList.add(musicMap)
        }
    }

    /**
     * 通过 SAF (Storage Access Framework) 读取文件内容。
     *
     * 【关键说明】：
     * 在 Android 11+ (API 30+) 的真机环境中，即使用户授予了 MANAGE_EXTERNAL_STORAGE 权限，
     * 直接使用 java.io.File API (如 readText()) 访问某些特定目录（如 /storage/emulated/0/...）
     * 下的文件时，仍可能因系统底层的 Linux 权限位限制或 Scoped Storage 策略拦截而抛出
     * EACCES (Permission denied) 异常。
     *
     * 解决方案：
     * 利用用户通过 ACTION_OPEN_DOCUMENT_TREE 授权并保存的 savedDirUri，
     * 通过 DocumentFile 和 ContentResolver.openInputStream() 进行流式读取。
     * 这种方式拥有系统级的持久化 URI 权限，能够稳定绕过上述文件句柄打开限制。
     */
    private fun readEntryJsonViaSAF(absolutePath: String): String? {
        if (savedDirUri == null) return null
        
        try {
            val rootPath = resolveRealPath(savedDirUri!!)
            if (rootPath != null && absolutePath.startsWith(rootPath)) {
                val relativePath = absolutePath.substring(rootPath.length).trim('/')
                var currentDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
                
                for (part in relativePath.split('/')) {
                    currentDoc = currentDoc?.findFile(part)
                    if (currentDoc == null) break
                }
                
                if (currentDoc != null && currentDoc.canRead()) {
                    val inputStream = contentResolver.openInputStream(currentDoc.uri)
                    val content = inputStream?.bufferedReader()?.use { it.readText() }
                    inputStream?.close()
                    return content
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun isSystemDirectory(path: String): Boolean {
        val lowerPath = path.lowercase()
        return lowerPath.startsWith("/system") ||
               lowerPath.startsWith("/proc") ||
               lowerPath.startsWith("/sys") ||
               lowerPath.startsWith("/dev") ||
               lowerPath.contains("/android/data") ||
               lowerPath.contains("/android/obb")
    }

    private fun listFilesNative(path: String?): List<Map<String, Any>> {
        val resultList = mutableListOf<Map<String, Any>>()
        if (path.isNullOrEmpty()) return resultList
        
        // 尝试使用 DocumentFile (SAF) 方式
        if (savedDirUri != null) {
            try {
                val parentDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
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
                        currentDoc.listFiles().forEach { doc ->
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
                e.printStackTrace()
            }
        }

        // 兜底：使用传统 File 方式
        try {
            val dir = File(path)
            if (dir.exists() && dir.isDirectory) {
                dir.listFiles()?.forEach { file ->
                    resultList.add(mapOf(
                        "name" to file.name,
                        "path" to file.absolutePath,
                        "isDirectory" to file.isDirectory
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return resultList
    }

    private fun getPlayableUri(path: String?): String? {
        if (path.isNullOrEmpty()) return null
        if (savedDirUri != null) {
            try {
                val rootPath = resolveRealPath(savedDirUri!!)
                if (rootPath != null && path.startsWith(rootPath)) {
                    val relativePath = path.substring(rootPath.length).trim('/')
                    var currentDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
                    for (part in relativePath.split('/')) {
                        currentDoc = currentDoc?.findFile(part)
                    }
                    if (currentDoc != null) {
                        return currentDoc.uri.toString()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return path
    }

    private fun readEntryJsonNative(path: String?): String? {
        if (path.isNullOrEmpty()) return null
        return readEntryJsonViaSAF(path) ?: run {
            try {
                val file = File(path)
                if (file.exists() && file.canRead()) file.readText() else null
            } catch (e: Exception) {
                null
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
            savedDirUri = uri
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
        val uriPath = uri.path ?: return null
        
        if (uriPath.contains("MuMuShared")) {
            val parts = uriPath.split(":")
            if (parts.size > 1) {
                val subPath = parts[1].replace("/tree/", "").replace("/document/", "")
                return File(Environment.getExternalStorageDirectory(), subPath).absolutePath
            }
        }
        
        if (uriPath.startsWith("/tree/primary:")) {
            val subPath = uriPath.replace("/tree/primary:", "")
            return File(Environment.getExternalStorageDirectory(), subPath).absolutePath
        }
        
        return Environment.getExternalStorageDirectory().absolutePath
    }
}
