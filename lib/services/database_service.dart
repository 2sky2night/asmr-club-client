import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/music.dart';

/// 数据库服务类，负责管理 SQLite 数据库的初始化和操作
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'asmr_club.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // 创建音乐表
        await db.execute(
          '''
          CREATE TABLE music (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            path TEXT NOT NULL UNIQUE,
            cover_url TEXT,
            author TEXT NOT NULL
          )
          ''',
        );
        // 创建搜索历史表
        await db.execute(
          '''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            keyword TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL
          )
          ''',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 升级到版本 2，添加搜索历史表
          await db.execute(
            '''
            CREATE TABLE IF NOT EXISTS search_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              keyword TEXT NOT NULL UNIQUE,
              created_at INTEGER NOT NULL
            )
            ''',
          );
        }
      },
    );
  }

  /// 插入音乐（如果路径已存在则忽略）
  Future<int> insertMusic(Music music) async {
    final db = await database;
    return await db.insert(
      'music',
      music.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 批量插入音乐
  Future<void> insertMusics(List<Music> musics) async {
    final db = await database;
    final batch = db.batch();
    for (var music in musics) {
      batch.insert(
        'music',
        music.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 获取所有音乐
  Future<List<Music>> getAllMusics() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('music');
    return List.generate(maps.length, (i) {
      return Music.fromMap(maps[i]);
    });
  }

  /// 根据路径检查音乐是否已存在
  Future<bool> isMusicExists(String path) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'music',
      where: 'path = ?',
      whereArgs: [path],
    );
    return result.isNotEmpty;
  }

  /// 清空所有音乐数据
  Future<void> clearAllMusics() async {
    final db = await database;
    await db.delete('music');
  }

  /// 根据 ID 删除单条音乐记录
  Future<void> deleteMusic(int id) async {
    final db = await database;
    await db.delete(
      'music',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 插入搜索历史（去重+更新时问戳）
  Future<void> insertSearchHistory(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'search_history',
      {'keyword': keyword.trim(), 'created_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取最近 30 条搜索历史
  Future<List<String>> getSearchHistories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'search_history',
      orderBy: 'created_at DESC',
      limit: 30,
    );
    return List.generate(maps.length, (i) => maps[i]['keyword'] as String);
  }

  /// 清空搜索历史
  Future<void> clearSearchHistories() async {
    final db = await database;
    await db.delete('search_history');
  }
}
