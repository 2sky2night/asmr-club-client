import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/music.dart';
import 'database_service.dart';

/// 媒体扫描服务类
class MediaScanner {
  final DatabaseService _dbService = DatabaseService();

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

  /// 递归扫描目录
  Future<void> _scanDirectoryRecursive(
    String dirPath, 
    int depth, 
    List<Music> musics,
    Set<String> processedPaths,
    String rootPath,
  ) async {
    if (depth > 8) return; // 进一步增加深度

    if (!dirPath.startsWith(rootPath) || _isSystemDirectory(dirPath)) return;

    try {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) return;

      if (depth <= 2) print('[SCAN] 正在扫描: $dirPath');

      final entities = directory.listSync(recursive: false);
      
      for (var entity in entities) {
        if (entity is Directory) {
          await _scanDirectoryRecursive(entity.path, depth + 1, musics, processedPaths, rootPath);
        } else if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          
          // 1. 如果发现音频文件，尝试向上寻找 entry.json
          if (lowerPath.endsWith('.mp3') || lowerPath.endsWith('.m4s') || lowerPath.endsWith('audio.m4s')) {
            await _processAudioFileWithMeta(entity, musics, processedPaths);
          }
        }
      }
    } catch (e) {
      // 忽略单个目录的错误，继续扫描其他目录
    }
  }

  /// 处理音频文件并尝试关联元数据
  Future<void> _processAudioFileWithMeta(File audioFile, List<Music> musics, Set<String> processedPaths) async {
    final audioPath = audioFile.path;
    if (processedPaths.contains(audioPath)) return;

    // 向上最多查找 3 层父目录寻找 entry.json
    Directory? currentDir = audioFile.parent;
    Map<String, dynamic>? meta;
    
    for (int i = 0; i < 3; i++) {
      if (currentDir == null) break;
      final entryFile = File(path.join(currentDir.path, 'entry.json'));
      if (entryFile.existsSync()) {
        try {
          // 尝试多种编码读取，优先 UTF-8，失败则尝试 latin1
          String content;
          try {
            content = await entryFile.readAsString(encoding: utf8);
          } catch (_) {
            content = await entryFile.readAsString(encoding: latin1);
          }
          
          // 清理可能存在的 BOM 头或非标准字符
          content = content.replaceAll(RegExp(r'[^\x20-\x7E\u4e00-\u9fa5\n\r\t]'), '');
          
          meta = jsonDecode(content) as Map<String, dynamic>;
          print('[SCAN] ✅ 成功解析元数据: ${meta['title']}');
          break;
        } catch (e) {
          print('[SCAN] ⚠️ 解析 entry.json 失败: ${entryFile.path}, 错误: $e');
        }
      }
      currentDir = currentDir.parent;
    }

    final exists = await _dbService.isMusicExists(audioPath);
    if (!exists) {
      processedPaths.add(audioPath);
      musics.add(Music(
        title: meta?['title']?.toString() ?? path.basenameWithoutExtension(audioPath),
        path: audioPath,
        coverUrl: meta?['cover']?.toString(),
        author: meta?['owner_name']?.toString() ?? '本地音乐',
      ));
      print('[SCAN] +++ 成功导入: ${path.basename(audioPath)}');
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
