import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/subtask.dart';
import '../models/todo.dart';
import '../utils/constants.dart';

const _defaultReminderTone = 'assets/sounds/alarm.wav';

/// The state shown by the Home sync button.
enum CloudSyncState { unavailable, signedOut, syncing, synced, error }

extension CloudSyncStateLabel on CloudSyncState {
  String get label {
    switch (this) {
      case CloudSyncState.unavailable:
        return 'Firebase setup required';
      case CloudSyncState.signedOut:
        return 'Cloud sync is off';
      case CloudSyncState.syncing:
        return 'Syncing tasks…';
      case CloudSyncState.synced:
        return 'Tasks synced';
      case CloudSyncState.error:
        return 'Sync needs attention';
    }
  }
}

/// A Firestore task document, including deletion tombstones.
class CloudTodoRecord {
  final String syncId;
  final bool deleted;
  final DateTime updatedAt;
  final Map<String, dynamic> data;

  const CloudTodoRecord({
    required this.syncId,
    required this.deleted,
    required this.updatedAt,
    required this.data,
  });

  factory CloudTodoRecord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final rawData = document.data();
    final data = rawData == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawData);
    final updatedAt = _dateFromCloud(data['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return CloudTodoRecord(
      syncId: (data['syncId'] as String?) ?? document.id,
      deleted: data['deleted'] == true,
      updatedAt: updatedAt,
      data: data,
    );
  }

  Todo toTodo({Todo? local}) {
    final createdAt = _dateFromCloud(data['createdAt']) ??
        local?.createdAt ??
        updatedAt;
    final completedValue = data['isCompleted'];
    final completed = completedValue is bool
        ? completedValue
        : (completedValue as num?)?.toInt() == 1;
    final storedStatus = (data['status'] as num?)?.toInt();
    final status = storedStatus != null &&
            storedStatus >= 0 &&
            storedStatus < TodoStatus.values.length
        ? TodoStatus.values[storedStatus]
        : (completed ? TodoStatus.done : TodoStatus.todo);
    final storedPriority = (data['priority'] as num?)?.toInt() ??
        (local?.priority.index ?? 1);
    final priority = storedPriority >= 0 &&
            storedPriority < Priority.values.length
        ? Priority.values[storedPriority]
        : (local?.priority ?? Priority.medium);

    return Todo(
      id: local?.id,
      syncId: syncId,
      title: (data['title'] as String?) ?? local?.title ?? 'Untitled task',
      description:
          (data['description'] as String?) ?? local?.description ?? '',
      isCompleted: completed,
      status: status,
      priority: priority,
      createdAt: createdAt,
      updatedAt: updatedAt,
      dueDate: _dateFromCloud(data['dueDate']),
      reminderTime: _dateFromCloud(data['reminderTime']),
      reminderIntervalHours:
          (data['reminderIntervalHours'] as num?)?.toInt() ??
              local?.reminderIntervalHours ??
              2,
      // Device-local custom tone paths cannot work on the other device. Keep
      // a local custom tone when a remote edit did not include a built-in one.
      reminderTone: (data['reminderTone'] as String?) ??
          local?.reminderTone ??
          _defaultReminderTone,
      category: (data['category'] as String?) ?? local?.category ?? 'General',
      // Image paths point into one device's documents directory. Attachments
      // stay local until Firebase Storage support is explicitly configured.
      imagePath: local?.imagePath,
      subtasks: _subtasksFromCloud(data['subtasks']),
    );
  }
}

class TodoSyncResult {
  final List<Todo> todos;
  final Set<String> deletedSyncIds;

  const TodoSyncResult({
    required this.todos,
    required this.deletedSyncIds,
  });
}

/// Firebase Auth + Firestore adapter for the app's offline-first SQLite data.
///
/// Firebase configuration is deliberately not committed to the repository.
/// Running `flutterfire configure` adds the private project's native config;
/// without it, the app continues working locally and reports sync as
/// unavailable instead of blocking startup.
class FirebaseSyncService extends ChangeNotifier {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;
  CloudSyncState _state = CloudSyncState.unavailable;
  String? _lastError;

  CloudSyncState get state => _state;
  String get stateLabel => _state.label;
  String? get lastError => _lastError;
  bool get isAvailable => _initialized;
  User? get user => _initialized ? _auth?.currentUser : null;
  bool get isSignedIn => user != null;

  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      if (Firebase.apps.isEmpty) {
        // Native Firebase configuration supplied by FlutterFire is used on
        // Android and iOS. Missing configuration is handled below so local
        // SQLite remains usable before the user connects Firebase.
        await Firebase.initializeApp();
      }
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _initialized = true;
      _lastError = null;
      _setState(
        _auth!.currentUser == null
            ? CloudSyncState.signedOut
            : CloudSyncState.synced,
      );

      _authSubscription ??= _auth!.authStateChanges().listen((user) {
        if (user == null) {
          _setState(CloudSyncState.signedOut);
        } else if (_state != CloudSyncState.syncing) {
          _setState(CloudSyncState.synced);
        }
      });
      // Wait for Firebase Auth's first state event so a persisted session is
      // available before TodoProvider decides whether startup sync is needed.
      await _auth!.authStateChanges().first;
      return true;
    } catch (error) {
      _initialized = false;
      _lastError =
          'Firebase is not configured. Run flutterfire configure first.';
      _setState(CloudSyncState.unavailable);
      return false;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!await initialize()) {
      throw StateError(_lastError ?? 'Firebase is not configured.');
    }
    _setState(CloudSyncState.syncing);
    try {
      await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _lastError = null;
      _setState(CloudSyncState.synced);
    } on FirebaseAuthException catch (error) {
      _setError(_authErrorMessage(error));
      rethrow;
    } catch (error) {
      _setError(error.toString());
      rethrow;
    }
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    if (!await initialize()) {
      throw StateError(_lastError ?? 'Firebase is not configured.');
    }
    _setState(CloudSyncState.syncing);
    try {
      await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _lastError = null;
      _setState(CloudSyncState.synced);
    } on FirebaseAuthException catch (error) {
      _setError(_authErrorMessage(error));
      rethrow;
    } catch (error) {
      _setError(error.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    await _auth!.signOut();
    _setState(CloudSyncState.signedOut);
  }

  Future<TodoSyncResult?> sync(Iterable<Todo> localTodos) async {
    if (!isSignedIn) return null;

    _setState(CloudSyncState.syncing);
    try {
      final snapshot = await _todoCollection.get();
      final remoteRecords = snapshot.docs
          .map(CloudTodoRecord.fromDocument)
          .toList(growable: false);
      final remoteById = <String, CloudTodoRecord>{
        for (final record in remoteRecords) record.syncId: record,
      };
      final localList = List<Todo>.of(localTodos);
      final localById = <String, Todo>{
        for (final todo in localList) todo.syncId: todo,
      };
      final merged = <Todo>[];
      final writes = <Todo>[];
      final deleted = <String>{};

      for (final local in localList) {
        final remote = remoteById[local.syncId];
        if (remote == null) {
          merged.add(local);
          writes.add(local);
        } else if (remote.deleted) {
          if (local.updatedAt.isAfter(remote.updatedAt)) {
            merged.add(local);
            writes.add(local);
          } else {
            deleted.add(local.syncId);
          }
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          merged.add(remote.toTodo(local: local));
        } else {
          merged.add(local);
          if (local.updatedAt.isAfter(remote.updatedAt)) {
            writes.add(local);
          }
        }
      }

      for (final remote in remoteRecords) {
        if (localById.containsKey(remote.syncId) || remote.deleted) continue;
        merged.add(remote.toTodo());
      }

      await _writeTodos(writes);
      _lastError = null;
      _setState(CloudSyncState.synced);
      return TodoSyncResult(todos: merged, deletedSyncIds: deleted);
    } catch (error) {
      _setError(_friendlySyncError(error));
      rethrow;
    }
  }

  Future<void> saveTodo(Todo todo) async {
    if (!isSignedIn) return;
    _setState(CloudSyncState.syncing);
    try {
      await _todoCollection.doc(todo.syncId).set(_cloudDataFor(todo));
      _lastError = null;
      _setState(CloudSyncState.synced);
    } catch (error) {
      _setError(_friendlySyncError(error));
      rethrow;
    }
  }

  Future<void> markDeleted(String syncId, DateTime updatedAt) async {
    if (!isSignedIn) return;
    _setState(CloudSyncState.syncing);
    try {
      await _todoCollection.doc(syncId).set({
        'syncId': syncId,
        'deleted': true,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      });
      _lastError = null;
      _setState(CloudSyncState.synced);
    } catch (error) {
      _setError(_friendlySyncError(error));
      rethrow;
    }
  }

  Stream<List<CloudTodoRecord>> watchTodos() {
    if (!isSignedIn) return Stream<List<CloudTodoRecord>>.empty();
    return _todoCollection.snapshots().map(
          (snapshot) => snapshot.docs
              .map(CloudTodoRecord.fromDocument)
              .toList(growable: false),
        );
  }

  CollectionReference<Map<String, dynamic>> get _todoCollection {
    final currentUser = user;
    if (currentUser == null || _firestore == null) {
      throw StateError('Sign in before syncing tasks.');
    }
    return _firestore!
        .collection('users')
        .doc(currentUser.uid)
        .collection('todos');
  }

  Future<void> _writeTodos(Iterable<Todo> todos) async {
    final pending = List<Todo>.of(todos);
    for (var offset = 0; offset < pending.length; offset += 400) {
      final end = offset + 400 < pending.length
          ? offset + 400
          : pending.length;
      final batch = _firestore!.batch();
      for (final todo in pending.sublist(offset, end)) {
        batch.set(_todoCollection.doc(todo.syncId), _cloudDataFor(todo));
      }
      await batch.commit();
    }
  }

  static Map<String, dynamic> _cloudDataFor(Todo todo) {
    final data = <String, dynamic>{
      'syncId': todo.syncId,
      'deleted': false,
      'title': todo.title,
      'description': todo.description,
      'isCompleted': todo.isCompleted,
      'status': todo.status.index,
      'priority': todo.priority.index,
      'createdAt': todo.createdAt.toUtc().toIso8601String(),
      'updatedAt': todo.updatedAt.toUtc().toIso8601String(),
      'dueDate': todo.dueDate?.toUtc().toIso8601String(),
      'reminderTime': todo.reminderTime?.toUtc().toIso8601String(),
      'reminderIntervalHours': todo.reminderIntervalHours,
      'category': todo.category,
      'subtasks': todo.subtasks.map((subtask) => subtask.toMap()).toList(),
    };

    // Built-in asset paths are valid on both devices. A custom local file
    // path is intentionally omitted instead of syncing a broken path.
    if (todo.reminderTone.startsWith('assets/')) {
      data['reminderTone'] = todo.reminderTone;
    }
    return data;
  }

  void _setState(CloudSyncState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }

  void _setError(String message) {
    _lastError = message;
    _setState(CloudSyncState.error);
  }

  static String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Use a stronger password (at least six characters).';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Try again when online.';
      default:
        return error.message ?? 'Firebase authentication failed.';
    }
  }

  static String _friendlySyncError(Object error) {
    if (error is FirebaseException &&
        error.code == 'permission-denied') {
      return 'Firestore denied access. Check the Firebase security rules.';
    }
    return 'Could not sync right now. Your local tasks are still safe.';
  }

  @override
  void dispose() {
    final subscription = _authSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }
}

DateTime? _dateFromCloud(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<Subtask> _subtasksFromCloud(dynamic raw) {
  if (raw is! List) return const <Subtask>[];
  return raw
      .whereType<Map>()
      .map((item) => Subtask.fromMap(Map<String, dynamic>.from(item)))
      .where((subtask) => subtask.title.trim().isNotEmpty)
      .toList();
}
