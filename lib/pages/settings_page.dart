import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/database_service.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('媒体扫描'),
            subtitle: const Text('从本地目录导入音乐'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              // 等待扫描页面返回结果
              final result = await Navigator.pushNamed(context, '/scan');
              if (result == true && context.mounted) {
                // 如果扫描成功，刷新播放列表
                context.read<PlayerProvider>().loadPlaylist();
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清空播放列表'),
            subtitle: const Text('删除所有已导入的音乐记录'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认清空'),
                  content: const Text('确定要删除所有音乐记录吗？此操作不可恢复。'),
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

              if (confirm == true && context.mounted) {
                await DatabaseService().clearAllMusics();
                context.read<PlayerProvider>().loadPlaylist();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('播放列表已清空')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: const Text('应用版本与更新日志'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.pushNamed(context, '/about');
            },
          ),
        ],
      ),
    );
  }
}
