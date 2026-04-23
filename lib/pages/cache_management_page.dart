import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/database_service.dart';

/// 缓存管理主页面
class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  int _imageCacheSizeBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImageCacheSize();
  }

  /// 加载图片缓存大小
  Future<void> _loadImageCacheSize() async {
    setState(() => _isLoading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final size = await _getTotalSizeOfFilesInDir(tempDir);
      setState(() {
        _imageCacheSizeBytes = size.toInt();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// 递归计算目录大小
  Future<int> _getTotalSizeOfFilesInDir(final FileSystemEntity file) async {
    if (file is File) {
      final length = await file.length();
      return length;
    }
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      int total = 0;
      for (final FileSystemEntity child in children) {
        total += await _getTotalSizeOfFilesInDir(child);
      }
      return total;
    }
    return 0;
  }

  /// 格式化缓存大小
  String _formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// 清除图片缓存
  Future<void> _clearImageCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有图片缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 清除 cached_network_image 缓存
        await DefaultCacheManager().emptyCache();
        
        // 同时清除临时目录
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
          await tempDir.create(recursive: true);
        }
        
        if (mounted) {
          await _loadImageCacheSize();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片缓存已清除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败: $e')),
          );
        }
      }
    }
  }

  /// 清除搜索历史
  Future<void> _clearSearchHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清空所有搜索历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DatabaseService().clearSearchHistories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('搜索历史已清空')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
      ),
      body: ListView(
        children: [
          // 图片缓存管理
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('图片缓存'),
            subtitle: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('当前大小: ${_formatCacheSize(_imageCacheSizeBytes)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _clearImageCache,
              tooltip: '清除图片缓存',
            ),
            onTap: () {
              // 可以跳转到更详细的图片缓存管理页面
              // 目前直接显示在列表中
            },
          ),
          const Divider(),
          // 搜索历史管理
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('搜索历史'),
            subtitle: const Text('清空搜索历史记录'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _clearSearchHistory,
              tooltip: '清空搜索历史',
            ),
          ),
        ],
      ),
    );
  }
}
