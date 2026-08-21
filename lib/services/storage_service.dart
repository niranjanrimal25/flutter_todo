import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo.dart';
import '../models/alarm.dart';

class StorageService {
  static Database? _database;

  static const int _dbVersion = 2;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'todos.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            priority INTEGER NOT NULL DEFAULT 1,
            createdAt TEXT NOT NULL,
            dueDate TEXT,
            reminderTime TEXT,
            category TEXT DEFAULT 'General'
          )
        ''');
        await db.execute('''
          CREATE TABLE alarms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            label TEXT DEFAULT 'Alarm',
            isEnabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE alarms(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              hour INTEGER NOT NULL,
              minute INTEGER NOT NULL,
              label TEXT DEFAULT 'Alarm',
              isEnabled INTEGER NOT NULL DEFAULT 1
            )
          ''');
        }
      },
    );
  }

  // ===== Todos =====

  static Future<int> insertTodo(Todo todo) async {
    final db = await database;
    return await db.insert('todos', todo.toMap());
  }

  static Future<List<Todo>> getAllTodos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'todos',
      orderBy: 'isCompleted ASC, priority DESC, dueDate ASC',
    );
    return maps.map((map) => Todo.fromMap(map)).toList();
  }

  static Future<int> updateTodo(Todo todo) async {
    final db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  static Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== Alarms =====

  static Future<int> insertAlarm(Alarm alarm) async {
    final db = await database;
    return await db.insert('alarms', alarm.toMap());
  }

  static Future<List<Alarm>> getAllAlarms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('alarms', orderBy: 'hour ASC, minute ASC');
    return maps.map((map) => Alarm.fromMap(map)).toList();
  }

  static Future<int> updateAlarm(Alarm alarm) async {
    final db = await database;
    return await db.update(
      'alarms',
      alarm.toMap(),
      where: 'id = ?',
      whereArgs: [alarm.id],
    );
  }

  static Future<int> deleteAlarm(int id) async {
    final db = await database;
    return await db.delete(
      'alarms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
