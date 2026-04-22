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

  /// 扫描 Bilibili 缓存目录
  Future<Map<String, int>> scanBilibiliCache(String directoryPath) async {
    print('[SCAN] 开始扫描目录: $directoryPath');
    int successCount = 0;
    int failedCount = 0;
    final List<Music> musicsToInsert = [];
    final Set<String> processedPaths = {}; // 用于内存去重

    // 处理 Android Content URI 或特殊路径
    String realPath = directoryPath;
    if (directoryPath.startsWith('content://')) {
      print('[SCAN] 警告: 检测到 Content URI，尝试解析...');
    }

    try {
      await _scanDirectoryRecursive(realPath, 0, musicsToInsert, processedPaths, realPath);
      
      if (musicsToInsert.isNotEmpty) {
        await _dbService.insertMusics(musicsToInsert);
        successCount = musicsToInsert.length;
      }
      print('[SCAN] 扫描完成。成功: $successCount, 失败: $failedCount');
    } catch (e) {
      print('[SCAN] 扫描过程中发生错误: $e');
      failedCount++;
    }

    return {'success': successCount, 'failed': failedCount};
  }

  /// 递归扫描目录（使用原生层列出文件以绕过权限限制）
  Future<void> _scanDirectoryRecursive(
    String dirPath, 
    int depth, 
    List<Music> musics,
    Set<String> processedPaths,
    String rootPath,
  ) async {
    if (depth > 8) return;
    if (!dirPath.startsWith(rootPath) || _isSystemDirectory(dirPath)) return;

    try {
      // 【核心修复】调用原生层获取文件列表
      final List<dynamic>? nativeFiles = await platform.invokeMethod('listFilesNative', {'path': dirPath});
      if (nativeFiles == null) return;

      if (depth <= 2) print('[SCAN] 正在扫描(原生): $dirPath');

      for (var item in nativeFiles) {
        final Map<dynamic, dynamic> fileInfo = item;
        final String filePath = fileInfo['path'];
        final bool isDir = fileInfo['isDirectory'];

        if (isDir) {
          await _scanDirectoryRecursive(filePath, depth + 1, musics, processedPaths, rootPath);
        } else {
          final lowerPath = filePath.toLowerCase();
          // 发现音频文件，尝试向上寻找 entry.json
          if (lowerPath.endsWith('.mp3') || lowerPath.endsWith('audio.m4s')) {
            await _processAudioFileWithMeta(File(filePath), musics, processedPaths);
          }
          // 明确忽略 video.m4s 或其他非音频文件
        }
      }
    } catch (e) {
      print('[SCAN] 原生扫描出错: $e');
    }
  }

  /// 处理音频文件并尝试关联元数据（使用原生层读取）
  Future<void> _processAudioFileWithMeta(File audioFile, List<Music> musics, Set<String> processedPaths) async {
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

    // 3. 执行导入
    if (bestAudioPath != null && !processedPaths.contains(bestAudioPath)) {
      final exists = await _dbService.isMusicExists(bestAudioPath);
      if (!exists) {
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
  }

  /// 处理独立的 MP3 文件
  Future<void> _processStandaloneMp3(File mp3File, List<Music> musics, Set<String> processedPaths) async {
    try {
      final audioPath = mp3File.path;
      
      // 内存去重
      if (processedPaths.contains(audioPath)) return;

      // 数据库去重
      final exists = await _dbService.isMusicExists(audioPath);
      if (!exists) {
        processedPaths.add(audioPath);
        musics.add(Music(
          title: path.basenameWithoutExtension(mp3File.path), // 使用文件名作为标题
          path: audioPath,
          author: '本地音乐',
        ));
        print('[SCAN] +++ 成功导入 MP3: ${path.basename(audioPath)}');
      } else {
        print('[SCAN] --- 数据库已存在 MP3: ${path.basename(audioPath)}');
      }
    } catch (e) {
      print('[SCAN] 💥 处理 MP3 失败: $e');
    }
  }

  /// 处理 entry.json 文件
  Future<void> _processEntryFile(File entryFile, List<Music> musics, Set<String> processedPaths) async {
    try {
      print('[SCAN] 🔍 开始解析: ${entryFile.path}');
      final content = await entryFile.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;

      final title = jsonMap['title']?.toString() ?? '未知标题';
      final coverUrl = jsonMap['cover']?.toString();
      final author = jsonMap['owner_name']?.toString() ?? '未知作者';

      print('[SCAN] 🎵 标题: $title, 作者: $author');

      // 尝试在同级目录或子目录查找 audio.m4s
      String? audioPath = await _findAudioFile(entryFile.parent);

      if (audioPath != null) {
        print('[SCAN] 🎧 找到音频文件: $audioPath');
        // 内存去重：如果这个音频路径在本次扫描中已经处理过，则跳过
        if (processedPaths.contains(audioPath)) {
          print('[SCAN] ⚠️ 跳过重复路径: $audioPath');
          return;
        }

        // 数据库去重：检查是否已存在于数据库中
        final exists = await _dbService.isMusicExists(audioPath);
        if (!exists) {
          processedPaths.add(audioPath);
          musics.add(Music(
            title: title,
            path: audioPath,
            coverUrl: coverUrl,
            author: author,
          ));
          print('[SCAN] +++ 成功导入: $title');
        } else {
          print('[SCAN] --- 数据库已存在: $title');
        }
      } else {
        print('[SCAN] ❌ 未找到关联的音频文件 (m4s/mp3)');
      }
    } catch (e) {
      print('[SCAN] 💥 解析 entry.json 失败: $e');
    }
  }

  /// 在目录及其子目录中查找音频文件
  Future<String?> _findAudioFile(Directory dir, {int depth = 0}) async {
    if (depth > 3) return null; // 限制递归深度，防止性能问题

    try {
      final entities = dir.listSync();
      for (var entity in entities) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          // 优先找 audio.m4s
          if (lowerPath.endsWith('audio.m4s')) return entity.path;
          // 其次找 .mp3
          if (lowerPath.endsWith('.mp3')) return entity.path;
        }
      }

      // 如果当前层没找到，进入子目录继续找
      for (var entity in entities) {
        if (entity is Directory) {
          final result = await _findAudioFile(entity, depth: depth + 1);
          if (result != null) return result;
        }
      }
    } catch (e) {
      // 忽略读取错误
    }

    return null;
  }

  /// 判断是否为系统敏感目录
  bool _isSystemDirectory(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.startsWith('/system') ||
           lowerPath.startsWith('/proc') ||
           lowerPath.startsWith('/sys') ||
           lowerPath.startsWith('/dev') ||
           lowerPath.contains('/android/data') ||
           lowerPath.contains('/android/obb');
  }
}
