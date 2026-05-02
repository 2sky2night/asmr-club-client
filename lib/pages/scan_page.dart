import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/media_scanner.dart';
import '../models/music.dart';

enum ScanStatus { idle, scanning, completed }

/// 媒体扫描页面
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _selectedDirectory;
  String _scanType = 'bilibili';
  ScanStatus _status = ScanStatus.idle;
  final MediaScanner _scanner = MediaScanner();
  static const platform = MethodChannel('com.example.asmr_club_client/path_resolver');
  static const scanEventChannel = EventChannel('com.example.asmr_club_client/scan_progress');
  
  List<Music> _foundMusics = [];
  int _successCount = 0;
  int _failedCount = 0;

  Future<void> _selectDirectory() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要存储权限才能扫描文件')),
          );
        }
        return;
      }
    }

    try {
      final String? path = await platform.invokeMethod('selectDirectory');
      if (path != null && path.isNotEmpty) {
        setState(() {
          _selectedDirectory = path;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录失败: ${e.message}')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    if (_selectedDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择扫描目录')),
      );
      return;
    }

    setState(() {
      _status = ScanStatus.scanning;
      _foundMusics.clear();
      _successCount = 0;
      _failedCount = 0;
    });

    // 监听实时进度
    final subscription = scanEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map<dynamic, dynamic>) {
        final music = Music(
          title: event['title'] as String? ?? '未知标题',
          path: event['path'] as String,
          coverUrl: event['cover'] as String?,
          author: event['author'] as String? ?? '本地音乐',
        );
        setState(() {
          _foundMusics.add(music);
        });
      }
    });

    try {
      // 触发原生扫描
      final result = await _scanner.scanBilibiliCache(_selectedDirectory!);
      
      await subscription.cancel();

      if (mounted) {
        setState(() {
          _successCount = result['success'] ?? 0;
          _failedCount = result['failed'] ?? 0;
          _status = ScanStatus.completed;
        });
      }
    } catch (e) {
      await subscription.cancel();
      if (mounted) {
        setState(() {
          _status = ScanStatus.idle;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描出错: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status != ScanStatus.scanning,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('媒体扫描'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case ScanStatus.idle:
        return _buildIdleView();
      case ScanStatus.scanning:
        return _buildScanningView();
      case ScanStatus.completed:
        return _buildCompletedView();
    }
  }

  Widget _buildIdleView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('扫描目录:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDirectory,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDirectory ?? '点击选择目录',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.folder),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('音乐类型:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _scanType,
          items: const [
            DropdownMenuItem(value: 'bilibili', child: Text('Bilibili 缓存视频')),
            DropdownMenuItem(value: 'normal', child: Text('普通音乐 (暂不支持)')),
          ],
          onChanged: (val) {
            if (val == 'normal') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('普通音乐类型暂未支持')),
              );
              return;
            }
            setState(() {
              _scanType = val!;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _startScan,
            child: const Text('开始扫描'),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningView() {
    return Column(
      children: [
        const SpinKitFadingCircle(color: Colors.blue, size: 30.0),
        const SizedBox(height: 16),
        Text('已发现 ${_foundMusics.length} 个音频文件', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: _foundMusics.length,
            itemBuilder: (context, index) {
              // 倒序展示：最新发现的在最上面
              final music = _foundMusics[_foundMusics.length - 1 - index];
              return ListTile(
                leading: const Icon(Icons.music_note, size: 20),
                title: Text(music.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(music.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    return Column(
      children: [
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 8),
                Text('成功导入: $_successCount 条', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_failedCount > 0) Text('跳过/失败: $_failedCount 条', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _foundMusics.length,
            itemBuilder: (context, index) {
              final music = _foundMusics[index];
              return ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(music.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(music.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('完成并返回'),
          ),
        ),
      ],
    );
  }
}
