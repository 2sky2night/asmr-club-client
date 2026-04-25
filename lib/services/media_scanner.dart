import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../models/music.dart';
import 'database_service.dart';

/// 媒体扫描服务类
class MediaScanner {
  final DatabaseService _dbService = DatabaseService();
  static const platform = MethodChannel('com.example.asmr_club_client/path_resolver');

  /// 用于 compute 调用的静态扫描方法 (Isolate 兼容)
  /// 仅负责扫描文件并返回 Music 列表，不涉及数据库操作
  static Future<List<Music>> scanBilibiliCacheStatic(String directoryPath) async {
    print('[SCAN-ISOLATE] 开始在后台隔离区扫描: $directoryPath');
    
    final List<Music> musicsToInsert = [];
    final Set<String> processedPaths = {};

    try {
      // 调用内部递归逻辑
      await _scanDirectoryRecursiveStatic(directoryPath, 0, musicsToInsert, processedPaths, directoryPath);
      print('[SCAN-ISOLATE] 扫描完成，找到 ${musicsToInsert.length} 个文件');
    } catch (e) {
      print('[SCAN-ISOLATE] 扫描过程中发生错误: $e');
    }

    return musicsToInsert;
  }

  /// 扫描 Bilibili 缓存目录 (主线程入口)
  Future<Map<String, int>> scanBilibiliCache(String directoryPath) async {
    // 1. 在后台 Isolate 中执行文件扫描
    final newMusics = await scanBilibiliCacheStatic(directoryPath);
    
    // 2. 在主线程中执行数据库去重和写入
    int successCount = 0;
    int failedCount = 0;
    
    try {
      final List<Music> musicsToInsert = [];
      for (final music in newMusics) {
        final exists = await _dbService.isMusicExists(music.path);
        if (!exists) {
          musicsToInsert.add(music);
        }
      }
      
      if (musicsToInsert.isNotEmpty) {
        await _dbService.insertMusics(musicsToInsert);
        successCount = musicsToInsert.length;
      }
    } catch (e) {
      print('[SCAN] 数据库写入失败: $e');
      failedCount = newMusics.length - successCount;
    }
    
    return {'success': successCount, 'failed': failedCount};
  }

  /// 递归扫描目录（静态方法，支持 Isolate）
  static Future<void> _scanDirectoryRecursiveStatic(
    String dirPath, 
    int depth, 
    List<Music> musics,
    Set<String> processedPaths,
    String rootPath,
  ) async {
    if (depth > 8) return;
    if (!dirPath.startsWith(rootPath) || _isSystemDirectoryStatic(dirPath)) return;

    try {
      // 【核心修复】调用原生层获取文件列表
      final List<dynamic>? nativeFiles = await platform.invokeMethod('listFilesNative', {'path': dirPath});
      if (nativeFiles == null) return;

      if (depth <= 2) print('[SCAN-ISOLATE] 正在扫描(原生): $dirPath');

      for (var item in nativeFiles) {
        final Map<dynamic, dynamic> fileInfo = item;
        final String filePath = fileInfo['path'];
        final bool isDir = fileInfo['isDirectory'];

        if (isDir) {
          await _scanDirectoryRecursiveStatic(filePath, depth + 1, musics, processedPaths, rootPath);
        } else {
          final lowerPath = filePath.toLowerCase();
          // 发现音频文件，尝试向上寻找 entry.json
          if (lowerPath.endsWith('.mp3') || lowerPath.endsWith('audio.m4s')) {
            await _processAudioFileWithMetaStatic(File(filePath), musics, processedPaths);
          }
        }
      }
    } catch (e) {
      print('[SCAN] 原生扫描出错: $e');
    }
  }

  /// 处理音频文件并尝试关联元数据（静态方法，支持 Isolate）
  static Future<void> _processAudioFileWithMetaStatic(File audioFile, List<Music> musics, Set<String> processedPaths) async {
    final audioPath = audioFile.path;
    if (processedPaths.contains(audioPath)) return;

    Directory? currentDir = audioFile.parent;
    Map<String, dynamic>? meta;
    String? bestAudioPath; // 用于记录当前目录下最优的音频路径
    
    // 1. 向上查找 entry.json 获取元数据
    for (int i = 0; i < 3; i++) {
      if (currentDir == null) break;
      final entryPath = path.join(currentDir.path, 'entry.json');
      
      try {
        final content = await platform.invokeMethod<String>('readEntryJsonNative', {'path': entryPath});
        if (content != null && content.isNotEmpty) {
          meta = jsonDecode(content) as Map<String, dynamic>;
          print('[SCAN] ✅ 成功解析元数据: ${meta['title']}');
          break;
        }
      } catch (e) { /* 忽略 */ }
      currentDir = currentDir.parent;
    }

    // 2. 确定当前目录下应该导入哪个音频文件（优先级：audio.m4s > mp3）
    // 如果当前扫描到的是 audio.m4s，直接导入
    if (audioPath.toLowerCase().endsWith('audio.m4s')) {
      bestAudioPath = audioPath;
    } 
    // 如果当前扫描到的是 mp3，需要检查同级目录下是否有 audio.m4s
    else if (audioPath.toLowerCase().endsWith('.mp3')) {
      final dirPath = audioFile.parent.path;
      final potentialM4s = path.join(dirPath, 'audio.m4s');
      
      // 通过原生层确认 audio.m4s 是否存在
      final m4sExists = await platform.invokeMethod<bool>('readEntryJsonNative', {'path': potentialM4s}) != null || 
                        File(potentialM4s).existsSync(); // 兜底检查
      
      if (!m4sExists) {
        bestAudioPath = audioPath;
      } else {
        print('[SCAN] ⏭️ 跳过 MP3，因为同目录存在 audio.m4s: $potentialM4s');
      }
    }

    // 3. 执行导入 (仅添加到列表，不检查数据库，由主线程统一处理)
    if (bestAudioPath != null && !processedPaths.contains(bestAudioPath)) {
      processedPaths.add(bestAudioPath);
      musics.add(Music(
        title: meta?['title']?.toString() ?? path.basenameWithoutExtension(bestAudioPath),
        path: bestAudioPath,
        coverUrl: meta?['cover']?.toString(),
        author: meta?['owner_name']?.toString() ?? '本地音乐',
      ));
      print('[SCAN] +++ 成功导入: ${path.basename(bestAudioPath)}');
    }
  }

  /// 判断是否为系统敏感目录 (静态方法)
  static bool _isSystemDirectoryStatic(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.startsWith('/system') ||
           lowerPath.startsWith('/proc') ||
           lowerPath.startsWith('/sys') ||
           lowerPath.startsWith('/dev') ||
           lowerPath.contains('/android/data') ||
           lowerPath.contains('/android/obb');
  }
}