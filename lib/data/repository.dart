import 'dart:async';

import '../models/task.dart';
import '../models/user_settings.dart';

class AppUser {
  const AppUser({required this.uid, required this.email, this.displayName});
  final String uid;
  final String email;
  final String? displayName;

  String get firstName {
    final n = (displayName ?? '').trim();
    if (n.isNotEmpty) return n.split(RegExp(r'\s+')).first;
    final local = email.split('@').first;
    return local.isEmpty ? 'there' : local;
  }
}

/// Friendly error the UI can show as-is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AuthService {
  Stream<AppUser?> get userChanges;
  AppUser? get currentUser;
  Future<void> signIn(String email, String password);

  /// Google sign-in. Creates the account on first use.
  Future<void> signInWithGoogle();
  Future<void> signUp(String name, String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> updateDisplayName(String name);
  Future<void> signOut();
}

abstract class TaskRepository {
  /// Every task for the signed-in user, archived ones included.
  /// Emits again whenever anything changes, on this device or another.
  Stream<List<Task>> watchTasks();

  Future<void> save(Task task);
  Future<void> delete(String taskId);

  /// One-off work to run after sign-in (e.g. importing legacy data).
  /// Returns how many tasks were imported.
  Future<int> prepare() async => 0;

  Future<UserSettings> loadSettings();
  Future<void> saveSettings(UserSettings settings);
}
