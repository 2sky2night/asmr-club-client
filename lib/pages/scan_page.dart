import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/media_scanner.dart';

/// 媒体扫描页面
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? _selectedDirectory;
  String _scanType = 'bilibili';
  bool _isScanning = false;
  final MediaScanner _scanner = MediaScanner();
  static const platform = MethodChannel('com.example.asmr_club_client/path_resolver');

  Future<void> _selectDirectory() async {
    // 请求存储权限
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
      // 调用原生方法获取真实路径，彻底解决 file_picker 在模拟器上的路径解析 bug
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
      _isScanning = true;
    });

    try {
      Map<String, int> result;
      if (_scanType == 'bilibili') {
        result = await _scanner.scanBilibiliCache(_selectedDirectory!);
      } else {
        result = {'success': 0, 'failed': 0};
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('扫描完成'),
            content: Text('成功导入: ${result['success']} 条\n导入失败: ${result['failed']} 条'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // 返回 true 给上一页，表示数据有更新
                  Navigator.pop(context, true); 
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描出错: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isScanning; // 扫描中不允许返回
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('媒体扫描'),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('扫描目录:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isScanning ? null : _selectDirectory,
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
                    onChanged: _isScanning ? null : (val) {
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
                      onPressed: _isScanning ? null : _startScan,
                      child: const Text('开始扫描'),
                    ),
                  ),
                ],
              ),
            ),
            
            // 全屏 Loading
            if (_isScanning)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        '媒体扫描中，请勿关闭当前页面',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
