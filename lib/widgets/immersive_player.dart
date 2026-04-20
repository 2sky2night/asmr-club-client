import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

/// 沉浸式播放器组件
class ImmersivePlayer extends StatelessWidget {
  const ImmersivePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, child) {
        final music = player.currentMusic;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 收起按钮
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => player.toggleImmersive(false),
                ),
              ),
              
              const Spacer(),
              
              // 封面图
              if (music?.coverUrl != null && music!.coverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    music.coverUrl!,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderCover(context),
                  ),
                )
              else
                _buildPlaceholderCover(context),
              
              const SizedBox(height: 40),
              
              // 音乐信息
              Text(
                music?.title ?? '未播放',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                music?.author ?? '',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              
              const Spacer(),
              
              // 进度条
              StreamBuilder<Duration>(
                stream: player.audioPlayer.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = player.audioPlayer.duration ?? Duration.zero;
                  
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        ),
                        child: Slider(
                          value: position.inSeconds.toDouble(),
                          max: duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0,
                          onChanged: (value) {
                            player.audioPlayer.seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position)),
                            Text(_formatDuration(duration)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: player.playPrevious,
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 56,
                    icon: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    onPressed: player.togglePlayPause,
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.skip_next),
                    onPressed: player.playNext,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 播放模式
              IconButton(
                icon: Icon(_getPlayModeIcon(player.playMode)),
                onPressed: player.togglePlayMode,
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderCover(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.music_note, size: 100, color: Colors.grey[600]),
    );
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.singleLoop:
        return Icons.repeat_one;
      case PlayMode.listOrder:
        return Icons.playlist_play;
      case PlayMode.listLoop:
        return Icons.repeat;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
