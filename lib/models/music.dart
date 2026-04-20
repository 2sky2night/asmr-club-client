/// 音乐数据模型
class Music {
  final int? id;
  final String title;
  final String path;
  final String? coverUrl;
  final String author;

  Music({
    this.id,
    required this.title,
    required this.path,
    this.coverUrl,
    required this.author,
  });

  /// 从数据库 Map 转换为 Music 对象
  factory Music.fromMap(Map<String, dynamic> map) {
    return Music(
      id: map['id'] as int?,
      title: map['title'] as String,
      path: map['path'] as String,
      coverUrl: map['cover_url'] as String?,
      author: map['author'] as String,
    );
  }

  /// 将 Music 对象转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'cover_url': coverUrl,
      'author': author,
    };
  }

  /// 复制并修改部分字段
  Music copyWith({
    int? id,
    String? title,
    String? path,
    String? coverUrl,
    String? author,
  }) {
    return Music(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      coverUrl: coverUrl ?? this.coverUrl,
      author: author ?? this.author,
    );
  }
}
