import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../providers/player_provider.dart';
import '../services/database_service.dart';
import '../widgets/immersive_player.dart';

/// 搜索建议数据类
class SearchSuggestion {
  final String text;
  final SuggestionType type;

  SearchSuggestion(this.text, this.type);
}

enum SuggestionType { history, music }

/// 首页：包含播放列表和底部播放器
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  List<String> _searchHistories = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSearchHistories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载搜索历史
  Future<void> _loadSearchHistories() async {
    final histories = await DatabaseService().getSearchHistories();
    if (mounted) {
      setState(() => _searchHistories = histories);
    }
  }

  /// 监听滚动
  void _onScroll() {
    final offset = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;
    // 降低阈值：滚动超过半屏就显示按钮，提升用户体验
    final showButton = offset > screenHeight * 0.5;
    
    if (showButton != _showScrollToTop) {
      setState(() => _showScrollToTop = showButton);
    }
  }

  /// 滚动到顶部
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
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
          body: Listener(
            onPointerDown: (event) {
              // 点击任何区域都失去焦点
              FocusScope.of(context).unfocus();
            },
            child: Stack(
              children: [
                // 播放列表
                Column(
                children: [
                  // 搜索框
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TypeAheadField<SearchSuggestion>(
                            controller: _searchController,
                            decorationBuilder: (context, child) {
                              return Material(
                                type: MaterialType.transparency,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            emptyBuilder: (context) => const SizedBox(height: 0),
                            itemBuilder: (context, suggestion) {
                              return ListTile(
                                leading: Icon(
                                  suggestion.type == SuggestionType.history 
                                      ? Icons.history 
                                      : Icons.music_note,
                                  size: 20, 
                                  color: suggestion.type == SuggestionType.history ? Colors.grey : Theme.of(context).primaryColor,
                                ),
                                title: Text(suggestion.text),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              );
                            },
                            onSelected: (suggestion) {
                              _searchController.text = suggestion.text;
                              player.searchPlaylist(suggestion.text);
                              if (suggestion.type == SuggestionType.history) {
                                DatabaseService().insertSearchHistory(suggestion.text);
                              }
                              _loadSearchHistories();
                            },
                            suggestionsCallback: (pattern) async {
                              await Future.delayed(Duration.zero); // 确保异步执行
                              
                              final lowerPattern = pattern.toLowerCase();
                              final List<SearchSuggestion> results = [];

                              if (pattern.isEmpty) {
                                // 空输入时只显示历史记录
                                for (final h in _searchHistories.take(5)) {
                                  results.add(SearchSuggestion(h, SuggestionType.history));
                                }
                                return results;
                              }
                              
                              // 匹配历史记录
                              for (final h in _searchHistories) {
                                if (h.toLowerCase().contains(lowerPattern)) {
                                  results.add(SearchSuggestion(h, SuggestionType.history));
                                  if (results.where((r) => r.type == SuggestionType.history).length >= 5) break;
                                }
                              }
                              
                              // 实时匹配音乐标题和作者
                              int musicCount = 0;
                              for (final m in player.playlist) {
                                if (m.title.toLowerCase().contains(lowerPattern) ||
                                    m.author.toLowerCase().contains(lowerPattern)) {
                                  results.add(SearchSuggestion(m.title, SuggestionType.music));
                                  musicCount++;
                                  if (musicCount >= 5) break;
                                }
                              }
                              
                              return results;
                            },
                            builder: (context, controller, focusNode) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: '搜索音乐名称或作者',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: controller.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            controller.clear();
                                            player.clearSearch();
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (value) {
                                  final keyword = value.trim();
                                  if (keyword.isNotEmpty) {
                                    player.searchPlaylist(keyword);
                                    DatabaseService().insertSearchHistory(keyword);
                                    _loadSearchHistories();
                                    FocusScope.of(context).unfocus();
                                  } else {
                                    player.clearSearch();
                                    FocusScope.of(context).unfocus();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: () {
                              final keyword = _searchController.text.trim();
                              if (keyword.isNotEmpty) {
                                player.searchPlaylist(keyword);
                                DatabaseService().insertSearchHistory(keyword);
                                _loadSearchHistories();
                                FocusScope.of(context).unfocus();
                              } else {
                                player.clearSearch();
                                FocusScope.of(context).unfocus();
                              }
                            },
                            child: const Text('搜索'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: player.displayPlaylist.isEmpty
                        ? _buildEmptyState(player)
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: player.displayPlaylist.length,
                            itemBuilder: (context, index) {
                              final music = player.displayPlaylist[index];
                              final originalIndex = player.playlist.indexOf(music);
                              final isPlaying = player.currentIndex == originalIndex;
                              
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: music.coverUrl != null && music.coverUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: music.coverUrl!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => _buildPlaceholderCover(context, size: 50),
                                          errorWidget: (context, url, error) => _buildPlaceholderCover(context, size: 50),
                                        )
                                      : _buildPlaceholderCover(context, size: 50),
                                ),
                                title: Text(
                                  music.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  player.playAt(originalIndex);
                                },
                                onLongPress: () {
                                  FocusScope.of(context).unfocus();
                                  player.playAt(originalIndex);
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
              
              // 滚动到顶部悬浮球
              if (_showScrollToTop)
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: AnimatedOpacity(
                    opacity: _showScrollToTop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: FloatingActionButton.small(
                      onPressed: _scrollToTop,
                      child: const Icon(Icons.keyboard_arrow_up),
                    ),
                  ),
                ),
            ],
          ),
        ),
        );
      },
    );
  }

  /// 空状态提示
  /// 空状态提示
  Widget _buildEmptyState(PlayerProvider player) {
    // 判断是否是搜索结果为空
    final isSearchResult = player.searchKeyword.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchResult ? Icons.search_off : Icons.music_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            isSearchResult ? '未找到匹配的音乐' : '播放列表为空',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (isSearchResult) ...[
            Text(
              '试试其他关键词',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                player.clearSearch();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重置搜索'),
            ),
          ] else
            Text(
              '请前往设置页面扫描媒体文件',
              style: TextStyle(color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  /// 占位封面图
  Widget _buildPlaceholderCover(BuildContext context, {required double size}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[300],
      child: const Icon(Icons.music_note, color: Colors.grey),
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
                  ? CachedNetworkImage(
                      imageUrl: player.currentMusic!.coverUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildPlaceholderCover(context, size: 40),
                      errorWidget: (context, url, error) => _buildPlaceholderCover(context, size: 40),
                    )
                  : _buildPlaceholderCover(context, size: 40),
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
