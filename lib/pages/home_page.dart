import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../services/database_service.dart';
import '../widgets/immersive_player.dart';

/// 首页：包含播放列表和底部播放器
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ASMR Club'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => player.loadPlaylist(),
              ),
            ],
          ),
          body: Stack(
            children: [
              // 播放列表
              Column(
                children: [
                  Expanded(
                    child: player.playlist.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: player.playlist.length,
                            itemBuilder: (context, index) {
                              final music = player.playlist[index];
                              final isPlaying = player.currentIndex == index;
                              
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: music.coverUrl != null && music.coverUrl!.isNotEmpty
                                      ? Image.network(music.coverUrl!, width: 50, height: 50, fit: BoxFit.cover)
                                      : Container(width: 50, height: 50, color: Colors.grey[300]),
                                ),
                                title: Text(
                                  music.title,
                                  style: TextStyle(
                                    fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                    color: isPlaying ? Theme.of(context).primaryColor : null,
                                  ),
                                ),
                                subtitle: Text(music.author),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPlaying)
                                      Icon(Icons.volume_up, color: Theme.of(context).primaryColor, size: 20),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () {
                                        _showMusicOptions(context, player, index);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => player.playAt(index),
                                onLongPress: () {
                                  player.playAt(index);
                                  player.toggleImmersive(true);
                                },
                              );
                            },
                          ),
                  ),
                  
                  // 底部迷你播放器
                  if (player.currentMusic != null)
                    _buildMiniPlayer(context, player),
                ],
              ),
              
              // 沉浸式播放器（全屏覆盖）
              if (player.isImmersive)
                Positioned.fill(
                  child: ImmersivePlayer(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 空状态提示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '播放列表为空',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '请前往设置页面扫描媒体文件',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// 底部迷你播放器
  Widget _buildMiniPlayer(BuildContext context, PlayerProvider player) {
    return GestureDetector(
      onTap: () => player.toggleImmersive(true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: player.currentMusic?.coverUrl != null
                  ? Image.network(player.currentMusic!.coverUrl!, width: 40, height: 40, fit: BoxFit.cover)
                  : Container(width: 40, height: 40, color: Colors.grey[300]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.currentMusic!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    player.currentMusic!.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                player.togglePlayPause();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示音乐选项菜单
  void _showMusicOptions(BuildContext context, PlayerProvider player, int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('从播放列表中移除'),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('确认移除'),
                    content: const Text('确定要将此音乐从播放列表中移除吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('确定', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  final music = player.playlist[index];
                  await DatabaseService().deleteMusic(music.id!);
                  player.loadPlaylist();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已从播放列表移除')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
