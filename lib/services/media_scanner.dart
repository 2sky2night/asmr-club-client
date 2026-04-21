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
    String rootPath, // 传入根路径用于校验
  ) async {
    if (depth > 5) return;

    // 安全检查：确保当前路径是根路径的子路径，防止跳出选定的目录
    if (!dirPath.startsWith(rootPath)) {
      print('[SCAN] 跳过非子目录路径: $dirPath');
      return;
    }

    // 跳过系统敏感目录
    if (_isSystemDirectory(dirPath)) return;

    try {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) {
        return;
      }

      // 仅在深度较浅时打印目录名，避免刷屏
      if (depth <= 2) {
        print('[SCAN] 正在扫描: $dirPath');
      }

      final entities = directory.listSync(recursive: false);
      
      for (var entity in entities) {
        if (entity is Directory) {
          // 再次校验子目录是否在根路径下（处理符号链接情况）
          if (entity.path.startsWith(rootPath)) {
            await _scanDirectoryRecursive(entity.path, depth + 1, musics, processedPaths, rootPath);
          }
        } else if (entity is File) {
          if (entity.path.endsWith('entry.json') && entity.path.startsWith(rootPath)) {
            print('[SCAN] >>> 发现 entry.json: ${entity.path}');
            await _processEntryFile(entity, musics, processedPaths);
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('Permission denied')) {
        return;
      }
      print('[SCAN] 扫描出错: $dirPath, 错误: $e');
    }
  }

  /// 处理 entry.json 文件
  Future<void> _processEntryFile(File entryFile, List<Music> musics, Set<String> processedPaths) async {
    try {
      final content = await entryFile.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;

      final title = jsonMap['title']?.toString() ?? '未知标题';
      final coverUrl = jsonMap['cover']?.toString();
      final author = jsonMap['owner_name']?.toString() ?? '未知作者';

      // 尝试在同级目录或子目录查找 audio.m4s
      String? audioPath = await _findAudioFile(entryFile.parent);

      if (audioPath != null) {
        // 内存去重：如果这个音频路径在本次扫描中已经处理过，则跳过
        if (processedPaths.contains(audioPath)) {
          print('[SCAN] 跳过重复路径: $audioPath');
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
        print('[SCAN] !!! 未找到 audio.m4s 对应文件');
      }
    } catch (e) {
      print('[SCAN] 解析 entry.json 失败: $e');
    }
  }

  /// 在目录及其子目录中查找音频文件
  Future<String?> _findAudioFile(Directory dir) async {
    // 1. 优先在同级目录查找 audio.m4s
    final directAudio = File(path.join(dir.path, 'audio.m4s'));
    if (directAudio.existsSync()) return directAudio.path;

    // 2. 若没找到，尝试在同级目录查找 .mp3 文件
    try {
      final entities = dir.listSync();
      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
          return entity.path;
        }
      }
    } catch (e) {
      // 忽略读取错误
    }

    // 3. 若同级还没找到，进入子目录查找 (递归深度限制为 2，防止性能问题)
    try {
      final subDirs = dir.listSync().whereType<Directory>();
      for (var subDir in subDirs) {
        // 先在子目录找标准的 audio.m4s
        final subAudio = File(path.join(subDir.path, 'audio.m4s'));
        if (subAudio.existsSync()) return subAudio.path;

        // 再在子目录找 mp3
        try {
          final subEntities = subDir.listSync();
          for (var entity in subEntities) {
            if (entity is File && entity.path.toLowerCase().endsWith('.mp3')) {
              return entity.path;
            }
          }
        } catch (e) {
          // 忽略深层目录错误
        }
      }
    } catch (e) {
      // 忽略子目录访问错误
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
