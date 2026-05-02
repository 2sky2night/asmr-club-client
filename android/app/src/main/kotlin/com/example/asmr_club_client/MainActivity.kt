package com.example.asmr_club_client

import android.content.Intent
import android.net.Uri
import android.os.Environment
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File
import androidx.documentfile.provider.DocumentFile
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.asmr_club_client/path_resolver"
    private val SCAN_EVENT_CHANNEL = "com.example.asmr_club_client/scan_progress"
    private val PICK_DIR_REQUEST_CODE = 1001
    private var resultCallback: MethodChannel.Result? = null
    private var scanEventSink: EventChannel.EventSink? = null
    private var savedDirUri: Uri? = null // 保存用户选择的目录 URI
    // 【性能优化】使用线程池并行处理耗时的 SAF 读取操作
    private val executor = Executors.newFixedThreadPool(4)
    // 【性能优化】缓存 DocumentFile 引用，避免重复进行耗时的路径解析
    private val docFileCache = mutableMapOf<String, DocumentFile?>()
    // 【核心优化】缓存目录级别的元数据，避免重复读取 entry.json
    private val metaCache = mutableMapOf<String, Map<String, Any>>()

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    scanEventSink = null
                }
            }
        )
    }

    private fun scanBilibiliCacheNative(rootPath: String?): List<Map<String, Any>> {
        if (rootPath.isNullOrEmpty()) return emptyList()
        val resultList = mutableListOf<Map<String, Any>>()
        val processedPaths = mutableSetOf<String>()
        docFileCache.clear() // 每次扫描前清空缓存
        
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
        depth: Int,
        currentDoc: DocumentFile? = null // 【核心优化】传入当前目录的 SAF 引用
    ) {
        if (depth > 8) return
        
        // 1. 尝试获取当前目录的 SAF 引用（如果上层没传下来，则尝试从缓存或根路径解析）
        var docForThisDir = currentDoc
        if (docForThisDir == null && savedDirUri != null) {
            val dirPath = dir.absolutePath
            if (docFileCache.containsKey(dirPath)) {
                docForThisDir = docFileCache[dirPath]
            } else {
                // 兜底：通过路径解析（仅在没有引用时发生）
                val rootPathResolved = resolveRealPath(savedDirUri!!)
                if (rootPathResolved != null && dirPath.startsWith(rootPathResolved)) {
                    val relativePath = dirPath.substring(rootPathResolved.length).trim('/')
                    var tempDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
                    for (part in relativePath.split('/')) {
                        tempDoc = tempDoc?.findFile(part)
                    }
                    docForThisDir = tempDoc
                    if (docForThisDir != null) docFileCache[dirPath] = docForThisDir
                }
            }
        }

        // 2. 利用 SAF 引用直接读取 entry.json（极速）
        if (docForThisDir != null) {
            val entryDoc = docForThisDir.findFile("entry.json")
            if (entryDoc != null && entryDoc.canRead()) {
                try {
                    val inputStream = contentResolver.openInputStream(entryDoc.uri)
                    val content = inputStream?.bufferedReader()?.use { it.readText() }
                    inputStream?.close()
                    
                    if (content != null && content.isNotEmpty()) {
                        val json = JSONObject(content)
                        val title = json.optString("title")
                        if (title.isNotEmpty()) {
                            metaCache[dir.absolutePath] = mapOf(
                                "title" to title,
                                "owner_name" to json.optString("owner_name"),
                                "cover" to json.optString("cover")
                            )
                        }
                    }
                } catch (e: Exception) { /* ignore */ }
            }
        }

        val files = dir.listFiles() ?: return
        for (file in files) {
            if (file.isDirectory) {
                if (file.absolutePath.startsWith(rootPath) && !isSystemDirectory(file.absolutePath)) {
                    // 3. 递归时，将子目录的 DocumentFile 引用传下去
                    val childDoc = docForThisDir?.findFile(file.name)
                    scanDirectoryRecursive(file, rootPath, resultList, processedPaths, depth + 1, childDoc)
                }
            } else {
                val lowerName = file.name.lowercase()
                if (lowerName.endsWith(".mp3") || lowerName == "audio.m4s") {
                    processAudioFileWithMetaFast(file, resultList, processedPaths)
                }
            }
        }
    }

    /**
     * 快速处理音频文件，直接从内存缓存获取元数据
     */
    private fun processAudioFileWithMetaFast(
        audioFile: File,
        resultList: MutableList<Map<String, Any>>,
        processedPaths: MutableSet<String>
    ) {
        val audioPath = audioFile.absolutePath
        if (processedPaths.contains(audioPath)) return

        var bestAudioPath: String? = null
        var meta: Map<String, Any>? = null

        // 1. 确定音频路径
        if (audioFile.name.lowercase() == "audio.m4s") {
            bestAudioPath = audioPath
        } else if (audioFile.name.lowercase().endsWith(".mp3")) {
            val potentialM4s = File(audioFile.parentFile, "audio.m4s")
            if (!potentialM4s.exists()) {
                bestAudioPath = audioPath
            }
        }

        if (bestAudioPath == null) return

        // 2. 从当前目录或父目录缓存中查找元数据
        var currentDir: File? = audioFile.parentFile
        for (i in 0..2) {
            if (currentDir == null) break
            val dirPath = currentDir.absolutePath
            if (metaCache.containsKey(dirPath)) {
                meta = metaCache[dirPath]
                break
            }
            currentDir = currentDir.parentFile
        }

        // 3. 添加到结果列表并推送进度
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
        
        // 【UI 优化】实时推送扫描进度到 Dart 层
        runOnUiThread {
            scanEventSink?.success(musicMap)
        }
    }


    /**
     * 通过 SAF 读取文件内容，并缓存 DocumentFile 引用以加速后续查找。
     */
    private fun readEntryJsonViaSAF(absolutePath: String): String? {
        if (savedDirUri == null) return null
        
        // 先查缓存
        if (docFileCache.containsKey(absolutePath)) {
            val cachedDoc = docFileCache[absolutePath]
            if (cachedDoc != null && cachedDoc.canRead()) {
                try {
                    val inputStream = contentResolver.openInputStream(cachedDoc.uri)
                    return inputStream?.bufferedReader()?.use { it.readText() }
                } catch (e: Exception) { /* ignore */ }
            }
        }

        try {
            val rootPath = resolveRealPath(savedDirUri!!)
            if (rootPath != null && absolutePath.startsWith(rootPath)) {
                val relativePath = absolutePath.substring(rootPath.length).trim('/')
                var currentDoc = DocumentFile.fromTreeUri(this, savedDirUri!!)
                
                // 优化：尝试从父目录缓存中恢复，减少查找步数
                val parentPath = absolutePath.substring(0, absolutePath.lastIndexOf('/'))
                if (docFileCache.containsKey(parentPath)) {
                    currentDoc = docFileCache[parentPath]
                }

                if (currentDoc != null) {
                    for (part in relativePath.split('/')) {
                        currentDoc = currentDoc?.findFile(part)
                        if (currentDoc == null) break
                    }
                }
                
                if (currentDoc != null && currentDoc.canRead()) {
                    docFileCache[absolutePath] = currentDoc // 存入缓存
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
