import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/todo.dart';
import '../models/alarm.dart';

class StorageService {
  static Database? _database;

  static const int _dbVersion = 7;

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
            reminderIntervalHours INTEGER NOT NULL DEFAULT 2,
            category TEXT DEFAULT 'General',
            imagePath TEXT,
            subtasks TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE alarms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            label TEXT DEFAULT 'Alarm',
            isEnabled INTEGER NOT NULL DEFAULT 1,
            ringtone TEXT NOT NULL DEFAULT 'assets/sounds/alarm.wav',
            repeatType INTEGER NOT NULL DEFAULT 0,
            repeatDays TEXT,
            nextTriggerAt TEXT
          )
        ''');
        await _createAppStateTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE alarms(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              hour INTEGER NOT NULL,
              minute INTEGER NOT NULL,
              label TEXT DEFAULT 'Alarm',
              isEnabled INTEGER NOT NULL DEFAULT 1,
              ringtone TEXT NOT NULL DEFAULT 'assets/sounds/alarm.wav'
            )
          ''');
        }
        if (oldVersion < 3) {
          await _createAppStateTable(db);
        }
        if (oldVersion < 4) {
          await db.execute('''
            ALTER TABLE alarms ADD COLUMN ringtone TEXT NOT NULL DEFAULT 'assets/sounds/alarm.wav'
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            ALTER TABLE todos ADD COLUMN imagePath TEXT
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            ALTER TABLE todos ADD COLUMN subtasks TEXT
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            ALTER TABLE todos ADD COLUMN reminderIntervalHours INTEGER NOT NULL DEFAULT 2
          ''');
          await db.execute('''
            ALTER TABLE alarms ADD COLUMN repeatType INTEGER NOT NULL DEFAULT 1
          ''');
          await db.execute('''
            ALTER TABLE alarms ADD COLUMN repeatDays TEXT
          ''');
          await db.execute('''
            ALTER TABLE alarms ADD COLUMN nextTriggerAt TEXT
          ''');
        }
      },
    );
  }

  static Future<void> _createAppStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE app_state(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
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
      // Keep persistence in the same order as the UI. TodoProvider also
      // sorts after filtering, so this is a fast initial order rather than
      // the only source of truth.
      orderBy: 'priority DESC, createdAt DESC',
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

  // ===== App state (key/value) =====

  static Future<void> saveAppState(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_state',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getAppState(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_state',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  static Future<void> deleteAppState(String key) async {
    final db = await database;
    await db.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}
