import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/todo.dart';
import '../models/alarm.dart';

class StorageService {
  static Database? _database;

  static const int _dbVersion = 11;

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
            syncId TEXT,
            title TEXT NOT NULL,
            description TEXT,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            status INTEGER NOT NULL DEFAULT 0,
            priority INTEGER NOT NULL DEFAULT 1,
            createdAt TEXT NOT NULL,
            updatedAt TEXT,
            dueDate TEXT,
            reminderTime TEXT,
            reminderIntervalHours INTEGER NOT NULL DEFAULT 2,
            reminderTone TEXT NOT NULL DEFAULT 'assets/sounds/alarm.wav',
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
        await _createHabitsTables(db);
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
        if (oldVersion < 8) {
          await db.execute('''
            ALTER TABLE todos ADD COLUMN reminderTone TEXT NOT NULL DEFAULT 'assets/sounds/alarm.wav'
          ''');
        }
        if (oldVersion < 9) {
          // Keep the existing completion flag for filters, notifications, and
          // older app code, while giving every task a Kanban column. Existing
          // completed tasks become Done; all other tasks start in To Do.
          await db.execute('''
            ALTER TABLE todos ADD COLUMN status INTEGER NOT NULL DEFAULT 0
          ''');
          await db.execute('''
            UPDATE todos SET status = 2 WHERE isCompleted = 1
          ''');
        }
        if (oldVersion < 10) {
          // Sync identity is separate from the local autoincrement id because
          // the same task has a different SQLite id on each device.
          await db.execute('''
            ALTER TABLE todos ADD COLUMN syncId TEXT
          ''');
          await db.execute('''
            ALTER TABLE todos ADD COLUMN updatedAt TEXT
          ''');
          await db.execute('''
            UPDATE todos SET updatedAt = createdAt WHERE updatedAt IS NULL
          ''');
        }
        if (oldVersion < 11) {
          await _createHabitsTables(db);
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

  static Future<void> _createHabitsTables(Database db) async {
    await db.execute('''
      CREATE TABLE habits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        icon TEXT,
        colorValue INTEGER,
        reminderHour INTEGER,
        reminderMinute INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE habit_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habitId INTEGER NOT NULL,
        date TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        UNIQUE(habitId, date),
        FOREIGN KEY(habitId) REFERENCES habits(id) ON DELETE CASCADE
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
    final todos = maps.map((map) => Todo.fromMap(map)).toList();

    // Version 10 added globally unique sync identities. Legacy rows get a
    // generated identity the first time they are loaded, then it is written
    // back so it stays stable across devices and app restarts.
    for (var index = 0; index < todos.length; index++) {
      if (maps[index]['syncId'] == null || maps[index]['updatedAt'] == null) {
        await updateTodo(todos[index]);
      }
    }
    return todos;
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

  // ===== Habits =====

  static Future<int> insertHabit(Habit habit) async {
    final db = await database;
    return db.insert('habits', habit.toMap());
  }

  static Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final maps = await db.query('habits', orderBy: 'createdAt ASC, id ASC');
    return maps.map(Habit.fromMap).toList();
  }

  static Future<int> updateHabit(Habit habit) async {
    final db = await database;
    return db.update(
      'habits',
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  static Future<int> deleteHabit(int id) async {
    final db = await database;
    await db.delete('habit_logs', where: 'habitId = ?', whereArgs: [id]);
    return db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<HabitLog>> getAllHabitLogs() async {
    final db = await database;
    final maps = await db.query('habit_logs', orderBy: 'date ASC, id ASC');
    return maps.map(HabitLog.fromMap).toList();
  }

  static Future<int> upsertHabitLog(HabitLog log) async {
    final db = await database;
    return db.insert(
      'habit_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
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
