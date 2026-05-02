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

  /// 扫描 Bilibili 缓存目录 (主线程入口)
  Future<Map<String, int>> scanBilibiliCache(String directoryPath) async {
    print('[SCAN] 开始扫描: $directoryPath');
    final List<Music> newMusics = [];
    
    try {
      // 【修复】直接在主线程调用原生方法，因为 MethodChannel 不能在 Isolate 中使用
      final List<dynamic>? nativeResults = await platform.invokeMethod('scanBilibiliCacheNative', {'path': directoryPath});
      
      if (nativeResults != null) {
        for (var item in nativeResults) {
          final Map<dynamic, dynamic> data = item;
          newMusics.add(Music(
            title: data['title'] as String? ?? '未知标题',
            path: data['path'] as String,
            coverUrl: data['cover'] as String?,
            author: data['author'] as String? ?? '本地音乐',
          ));
        }
      }
      print('[SCAN] 原生扫描完成，收到 ${newMusics.length} 个文件');
    } catch (e) {
      print('[SCAN] 扫描过程中发生错误: $e');
      return {'success': 0, 'failed': 0};
    }
    
    // 在主线程中执行数据库去重和写入
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

}