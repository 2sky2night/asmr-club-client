import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:text_scroll/text_scroll.dart';
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
          padding: const EdgeInsets.only(bottom: 80),
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
                  child: CachedNetworkImage(
                    imageUrl: music.coverUrl!,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildPlaceholderCover(context),
                    errorWidget: (context, url, error) => _buildPlaceholderCover(context),
                  ),
                )
              else
                _buildPlaceholderCover(context),
                
              const SizedBox(height: 40),
                
              // 音乐信息（标题跑马灯）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextScroll(
                  music?.title ?? '未播放',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  mode: TextScrollMode.endless,
                  velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
                  delayBefore: const Duration(seconds: 2),
                  pauseBetween: const Duration(seconds: 2),
                  selectable: true,
                ),
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
                
              const SizedBox(height: 32),
                
              // 控制按钮区域
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 播放模式按钮
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      icon: Icon(
                        _getPlayModeIcon(player.playMode),
                        size: 24,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onPressed: player.togglePlayMode,
                    ),
                  ),
                    
                  // 上一首
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: player.playPrevious,
                  ),
                    
                  // 播放/暂停（主按钮）
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 48,
                      icon: Icon(
                        player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: player.togglePlayPause,
                    ),
                  ),
                    
                  // 下一首
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: player.playNext,
                  ),
                    
                  // 占位（保持对称）
                  const SizedBox(width: 48),
                ],
              ),
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
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      final hoursString = twoDigits(hours);
      return '$hoursString:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
