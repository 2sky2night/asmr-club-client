import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import '../models/music.dart';
import '../services/database_service.dart';

/// 播放模式枚举
enum PlayMode {
  singleLoop, // 单曲循环
  listOrder,  // 列表顺序播放
  listLoop,   // 列表循环播放
}

Future<PlayerProvider> initAudioService() async {
  print('[AudioService] Starting initialization...');
  try {
    final player = await AudioService.init(
      builder: () => PlayerProvider(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.asmr_club_client.channel.audio',
        androidNotificationChannelName: 'ASMR Club Playback',
        androidNotificationOngoing: true,
      ),
    );
    print('[AudioService] Initialization successful.');
    return player;
  } catch (e) {
    print('[AudioService] Initialization failed: $e');
    rethrow;
  }
}

/// 播放器状态管理类
class PlayerProvider extends BaseAudioHandler with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DatabaseService _dbService = DatabaseService();

  List<Music> _playlist = [];
  int _currentIndex = -1;
  PlayMode _playMode = PlayMode.listLoop;
  bool _isImmersive = false;
  
  // 搜索相关状态
  String _searchKeyword = '';
  List<Music> _filteredPlaylist = [];

  // Getters
  AudioPlayer get audioPlayer => _audioPlayer;
  List<Music> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  Music? get currentMusic => _currentIndex >= 0 && _currentIndex < _playlist.length ? _playlist[_currentIndex] : null;
  PlayMode get playMode => _playMode;
  bool get isImmersive => _isImmersive;
  bool get isPlaying => _audioPlayer.playing;
  
  // 搜索相关 Getters
  String get searchKeyword => _searchKeyword;
  List<Music> get displayPlaylist => _searchKeyword.isEmpty ? _playlist : _filteredPlaylist;

  PlayerProvider() {
    _initPlayer();
    loadPlaylist();
  }

  /// 初始化播放器监听
  void _initPlayer() {
    print('[AudioService] Initializing player listeners...');
    
    // 1. 立即发送一个初始的 PlaybackState，确保通知栏通道被建立
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
    ));

    _audioPlayer.playerStateStream.listen((state) {
      print('[AudioService] Player state changed: ${state.processingState}, playing: ${state.playing}');
      if (state.processingState == ProcessingState.completed) {
        _handleSongCompleted();
      }
      _updateMediaItem();
      
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[state.processingState]!,
        playing: state.playing,
        updatePosition: _audioPlayer.position,
        bufferedPosition: _audioPlayer.bufferedPosition,
        speed: _audioPlayer.speed,
        queueIndex: _currentIndex,
      ));
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  /// 更新系统媒体通知栏信息
  void _updateMediaItem() {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      final music = _playlist[_currentIndex];
      print('[AudioService] Updating MediaItem: ${music.title}');
      final item = MediaItem(
        id: music.id.toString(),
        title: music.title,
        artist: music.author,
        artUri: music.coverUrl != null ? Uri.parse(music.coverUrl!) : null,
      );
      mediaItem.add(item);
      // 强制触发一次 playbackState 更新，确保通知栏刷新
      if (playbackState.value.playing) {
        playbackState.add(playbackState.value.copyWith(
          updatePosition: _audioPlayer.position,
        ));
      }
    }
  }

  /// 加载播放列表
  Future<void> loadPlaylist() async {
    _playlist = await _dbService.getAllMusics();
    notifyListeners();
  }

  /// 播放指定索引的音乐
  Future<void> playAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    final music = _playlist[index];
    
    try {
      // 【核心修复】通过原生层获取可播放的 Uri
      String? uriString;
      try {
        uriString = await const MethodChannel('com.example.asmr_club_client/path_resolver')
            .invokeMethod<String>('getPlayableUri', {'path': music.path});
      } catch (e) {
        print('获取 URI 失败: $e');
      }

      if (uriString != null && uriString.isNotEmpty) {
        // 如果是 content:// URI，使用 AudioSource.uri
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(uriString)));
      } else {
        // 否则使用本地文件路径
        await _audioPlayer.setFilePath(music.path);
      }
      
      await _audioPlayer.play();
    } catch (e) {
      print('播放失败: $e');
    }
    notifyListeners();
  }

  /// 播放/暂停切换
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      if (_currentIndex == -1 && _playlist.isNotEmpty) {
        await playAt(0);
      } else {
        await _audioPlayer.play();
      }
    }
    notifyListeners();
  }

  /// 上一首
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;
    
    int newIndex;
    if (_playMode == PlayMode.listOrder && _currentIndex == 0) {
      return; // 列表顺序播放且是第一首时不操作
    } else {
      newIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }
    await playAt(newIndex);
  }

  /// 下一首
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    int newIndex;
    if (_playMode == PlayMode.listOrder && _currentIndex == _playlist.length - 1) {
      return; // 列表顺序播放且是最后一首时不操作
    } else {
      newIndex = (_currentIndex + 1) % _playlist.length;
    }
    await playAt(newIndex);
  }

  /// 切换播放模式
  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.singleLoop:
        _playMode = PlayMode.listOrder;
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
      case PlayMode.listOrder:
        _playMode = PlayMode.listLoop;
        _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case PlayMode.listLoop:
        _playMode = PlayMode.singleLoop;
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
    }
    notifyListeners();
  }

  /// 处理歌曲播放完成
  void _handleSongCompleted() {
    if (_playMode == PlayMode.singleLoop) {
      _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } else if (_playMode == PlayMode.listLoop || _currentIndex < _playlist.length - 1) {
      playNext();
    }
  }

  /// 切换沉浸式模式
  void toggleImmersive(bool value) {
    _isImmersive = value;
    notifyListeners();
  }

  /// 搜索播放列表
  void searchPlaylist(String keyword) {
    _searchKeyword = keyword.trim();
    if (_searchKeyword.isEmpty) {
      _filteredPlaylist = [];
    } else {
      final lowerKeyword = _searchKeyword.toLowerCase();
      _filteredPlaylist = _playlist.where((music) {
        return music.title.toLowerCase().contains(lowerKeyword) ||
               music.author.toLowerCase().contains(lowerKeyword);
      }).toList();
    }
    notifyListeners();
  }

  /// 清空搜索
  void clearSearch() {
    _searchKeyword = '';
    _filteredPlaylist = [];
    notifyListeners();
  }

  @override
  Future<void> play() async {
    print('[AudioService] Override play() called');
    await _audioPlayer.play();
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
    ));
  }

  @override
  Future<void> pause() async {
    print('[AudioService] Override pause() called');
    await _audioPlayer.pause();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
    ));
  }

  @override
  Future<void> skipToNext() async {
    await playNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await playPrevious();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
