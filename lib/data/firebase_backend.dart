import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import 'repository.dart';

AppUser? _toAppUser(User? u) => u == null
    ? null
    : AppUser(uid: u.uid, email: u.email ?? '', displayName: u.displayName);

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> get userChanges => _auth.userChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<void> signIn(String email, String password) => _guard(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
        } else {
          await _auth.signInWithProvider(provider);
        }
      });

  @override
  Future<void> signUp(String name, String email, String password) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        await cred.user?.updateDisplayName(name.trim());
        await cred.user?.reload();
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> updateDisplayName(String name) => _guard(() async {
        await _auth.currentUser?.updateDisplayName(name.trim());
        await _auth.currentUser?.reload();
      });

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  static String _message(String code) => switch (code) {
        'invalid-email' => 'That email address doesn\'t look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Use at least 6 characters for your password.',
        'too-many-requests' =>
          'Too many attempts. Wait a minute and try again.',
        'network-request-failed' => 'No connection. Check your internet.',
        'popup-closed-by-user' ||
        'cancelled-popup-request' ||
        'web-context-canceled' ||
        'canceled' =>
          'Google sign-in was cancelled.',
        'popup-blocked' =>
          'Your browser blocked the Google sign-in window. Allow pop-ups for this site and try again.',
        'account-exists-with-different-credential' =>
          'This email already has an account. Sign in with your password instead.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled for this app yet.',
        'unauthorized-domain' =>
          'Google sign-in is not allowed on this web address yet.',
        _ => 'Something went wrong ($code). Please try again.',
      };
}

/// Tasks live at `users/{uid}/tasks/{taskId}`, one document per task with its
/// steps embedded. Firestore keeps an offline cache, so the app works without
/// a connection and syncs when it's back.
class FirestoreTaskRepository extends TaskRepository {
  FirestoreTaskRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _tasks =>
      _userDoc.collection('tasks');

  @override
  Stream<List<Task>> watchTasks() => _tasks.snapshots().map(
      (snap) => snap.docs.map((d) => _fromDoc(d.id, d.data())).toList());

  @override
  Future<void> save(Task task) => _tasks.doc(task.id).set(_toDoc(task));

  @override
  Future<void> delete(String taskId) => _tasks.doc(taskId).delete();

  Map<String, dynamic> _toDoc(Task t) => {
        ...t.toMap(),
        'dueDate': t.dueDate == null ? null : Timestamp.fromDate(t.dueDate!),
        'completedAt':
            t.completedAt == null ? null : Timestamp.fromDate(t.completedAt!),
        'createdAt': Timestamp.fromDate(t.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static DateTime? _date(Object? v) => switch (v) {
        Timestamp ts => ts.toDate(),
        DateTime d => d,
        _ => null,
      };

  static Task _fromDoc(String id, Map<String, dynamic> m) {
    final now = DateTime.now();
    final steps = (m['steps'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => TaskStep.fromMap(Map<String, dynamic>.from(s)))
        .toList();
    return Task(
      id: id,
      title: (m['title'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      status: TaskStatus.fromCode(m['status']),
      priority: Priority.fromCode(m['priority']),
      dueDate: _date(m['dueDate']),
      tags: (m['tags'] as List? ?? const []).whereType<String>().toList(),
      steps: steps,
      currentStepId: m['currentStepId'] as String?,
      archived: (m['archived'] as bool?) ?? false,
      createdAt: _date(m['createdAt']) ?? now,
      // A pending server timestamp reads as null until the write lands.
      updatedAt: _date(m['updatedAt']) ?? now,
      completedAt: _date(m['completedAt']),
    );
  }

  /// Copies tasks from the old Realtime Database layout
  /// (`users/{uid}/data`, a JSON string holding the whole list) into
  /// Firestore, once per account. The old data is left untouched.
  @override
  Future<int> prepare() async {
    try {
      final profile = await _userDoc.get();
      if (profile.data()?['legacyImportedAt'] != null) return 0;

      final snap = await FirebaseDatabase.instance.ref('users/$_uid').get();
      final legacy = snap.value;
      var imported = 0;
      String? username;

      if (legacy is Map) {
        username = legacy['username'] as String?;
        final raw = legacy['data'];
        final list = raw is String ? jsonDecode(raw) : raw;
        if (list is List) {
          final batch = _db.batch();
          for (final item in list.whereType<Map>()) {
            final t = legacyToTask(Map<String, dynamic>.from(item));
            batch.set(_tasks.doc(t.id), _toDoc(t));
            imported++;
          }
          await batch.commit();
        }
      }

      await _userDoc.set({
        'legacyImportedAt': FieldValue.serverTimestamp(),
        'legacyTaskCount': imported,
      }, SetOptions(merge: true));

      final user = FirebaseAuth.instance.currentUser;
      if (username != null &&
          username.trim().isNotEmpty &&
          (user?.displayName ?? '').isEmpty) {
        await user?.updateDisplayName(username.trim());
        await user?.reload();
      }
      return imported;
    } catch (e) {
      // Import is best-effort: a missing or locked legacy node must never
      // keep someone out of the app.
      debugPrint('Legacy import skipped: $e');
      return 0;
    }
  }
}

/// Maps one task from the original app's JSON format.
Task legacyToTask(Map<String, dynamic> j) {
  final now = DateTime.now();
  final rawSteps = (j['steps'] as List? ?? const []).whereType<Map>().toList();
  final steps = <TaskStep>[];
  String? currentStepId;
  final currentNo = j['current_step'];
  for (var i = 0; i < rawSteps.length; i++) {
    final s = rawSteps[i];
    final no = s['no'] ?? i + 1;
    final id = 'step$no';
    steps.add(TaskStep(
      id: id,
      title: '${s['content'] ?? ''}',
      note: '${s['comment'] ?? ''}',
      status: TaskStatus.fromCode(s['status']),
    ));
    if (no == currentNo) currentStepId = id;
  }
  final status = TaskStatus.fromCode(j['status']);
  final rawId = j['id'];
  return Task(
    id: rawId is String && rawId.isNotEmpty && !rawId.contains('/')
        ? rawId
        : newId(),
    title: '${j['task_name'] ?? 'Untitled task'}',
    description: '${j['description'] ?? ''}',
    status: status,
    steps: steps,
    currentStepId: currentStepId,
    archived: j['archived'] == true,
    createdAt: now,
    updatedAt: now,
    completedAt: status == TaskStatus.done ? now : null,
  );
}
