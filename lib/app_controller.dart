import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repository.dart';
import 'models/task.dart';
import 'models/user_settings.dart';
import 'models/reminders.dart';
import 'platform/reminders.dart';
import 'platform/timezone.dart';

enum TaskFilter { active, today, upcoming, done, all }

enum TaskSort { smart, dueDate, priority, recent }

/// Holds the signed-in user, their live task list and UI preferences.
class AppController extends ChangeNotifier {
  AppController({
    required this.auth,
    required TaskRepository Function(AppUser user) repositoryFor,
    ReminderScheduler? reminders,
  })  : _repositoryFor = repositoryFor,
        reminders = reminders ?? FakeReminderScheduler(supported: false) {
    _authSub = auth.userChanges.listen(_onUser);
    _loadPrefs();
  }

  final AuthService auth;

  /// On-device reminder notifications (iPhone).
  final ReminderScheduler reminders;
  Timer? _replanTimer;
  final TaskRepository Function(AppUser user) _repositoryFor;

  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<List<Task>>? _taskSub;
  TaskRepository? _repo;

  bool authResolved = false;
  AppUser? user;
  bool tasksLoaded = false;
  List<Task> _tasks = const [];
  int? lastImportCount;
  UserSettings settings = const UserSettings();
  Object? syncError;

  ThemeMode themeMode = ThemeMode.system;
  TaskSort sort = TaskSort.smart;

  List<Task> get allTasks => _tasks;
  List<Task> get liveTasks => _tasks.where((t) => !t.archived).toList();
  List<Task> get archivedTasks =>
      _sorted(_tasks.where((t) => t.archived).toList(), TaskSort.recent);

  Task? taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---- auth / data wiring -------------------------------------------------

  Future<void> _onUser(AppUser? u) async {
    final changedAccount = u?.uid != user?.uid;
    user = u;
    authResolved = true;
    if (changedAccount) {
      await _taskSub?.cancel();
      _taskSub = null;
      _repo = null;
      _tasks = const [];
      settings = const UserSettings();
      tasksLoaded = false;
      syncError = null;
      if (u != null) {
        final repo = _repositoryFor(u);
        _repo = repo;
        notifyListeners();
        final imported = await repo.prepare();
        if (!identical(_repo, repo)) return; // signed out meanwhile
        if (imported > 0) lastImportCount = imported;
        _loadSettings(repo);
        _taskSub = repo.watchTasks().listen((tasks) {
          _tasks = tasks;
          tasksLoaded = true;
          syncError = null;
          notifyListeners();
        }, onError: (Object e) {
          syncError = e;
          tasksLoaded = true;
          notifyListeners();
        });
      }
    }
    notifyListeners();
  }

  // ---- task operations ----------------------------------------------------
  // Each write updates the local list straight away so the UI never waits on
  // the network; the live listener then confirms (or corrects) it.

  Future<void> save(Task task) async {
    final updated = task.copyWith(updatedAt: DateTime.now());
    final i = _tasks.indexWhere((t) => t.id == task.id);
    _tasks = [..._tasks];
    if (i >= 0) {
      _tasks[i] = updated;
    } else {
      _tasks.add(updated);
    }
    notifyListeners();
    await _repo?.save(updated);
  }

  Future<void> delete(String id) async {
    _tasks = _tasks.where((t) => t.id != id).toList();
    notifyListeners();
    await _repo?.delete(id);
  }

  Future<void> setArchived(Task t, bool archived) =>
      save(t.copyWith(archived: archived));

  Future<void> cycleStatus(Task t) {
    if (t.steps.isEmpty) return save(t.withStatus(t.status.next));
    // With steps, "complete" means ticking all of them, and re-opening
    // clears them, so the progress bar always matches the status.
    if (t.isDone) {
      return save(t
          .copyWith(steps: [
            for (final s in t.steps) s.copyWith(status: TaskStatus.notStarted)
          ])
          .withStatus(TaskStatus.notStarted));
    }
    return save(t
        .copyWith(steps: [
          for (final s in t.steps) s.copyWith(status: TaskStatus.done)
        ])
        .withStatus(TaskStatus.done));
  }

  Future<void> toggleStep(Task t, TaskStep s) => save(t.withStep(
      s.copyWith(status: s.isDone ? TaskStatus.notStarted : TaskStatus.done)));

  Future<void> setStepStatus(Task t, TaskStep s, TaskStatus st) =>
      save(t.withStep(s.copyWith(status: st)));

  Future<void> setCurrentStep(Task t, TaskStep s) {
    var next = t.copyWith(currentStepId: s.id);
    if (s.status == TaskStatus.notStarted) {
      next = next.withStep(s.copyWith(status: TaskStatus.inProgress));
    }
    return save(next);
  }

  // ---- queries -------------------------------------------------------------

  List<Task> filtered(TaskFilter f, {String? tag}) {
    final today = TaskDates.today();
    final tomorrow = today.add(const Duration(days: 1));
    Iterable<Task> list = liveTasks;
    if (tag != null) list = list.where((t) => t.tags.contains(tag));
    list = switch (f) {
      TaskFilter.active => list.where((t) => !t.isDone),
      // A task counts as due when it, or any of its open steps, is due.
      TaskFilter.today => list.where((t) =>
          !t.isDone &&
          ((t.dueDate != null && t.dueDate!.isBefore(tomorrow)) ||
              t.datedOpenSteps.any((st) => st.dueDate!.isBefore(tomorrow)))),
      TaskFilter.upcoming => list.where((t) =>
          !t.isDone &&
          ((t.dueDate != null && !t.dueDate!.isBefore(tomorrow)) ||
              t.datedOpenSteps.any((st) => !st.dueDate!.isBefore(tomorrow)))),
      TaskFilter.done => list.where((t) => t.isDone),
      TaskFilter.all => list,
    };
    return _sorted(list.toList(), f == TaskFilter.done ? TaskSort.recent : sort);
  }

  int count(TaskFilter f) => filtered(f).length;

  List<String> get allTags {
    final tags = <String>{};
    for (final t in liveTasks) {
      tags.addAll(t.tags);
    }
    return tags.toList()..sort();
  }

  int get completedThisWeek {
    final cutoff = TaskDates.today().subtract(const Duration(days: 6));
    return _tasks
        .where((t) => t.completedAt != null && !t.completedAt!.isBefore(cutoff))
        .length;
  }

  List<Task> search(String q) {
    final terms = q.toLowerCase().split(RegExp(r'\s+'))..removeWhere((e) => e.isEmpty);
    if (terms.isEmpty) return const [];
    return _sorted(
      _tasks.where((t) {
        final text = t.searchText;
        return terms.every(text.contains);
      }).toList(),
      TaskSort.recent,
    );
  }

  static List<Task> _sorted(List<Task> list, TaskSort sort) {
    int byDue(Task a, Task b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    }

    int byRecent(Task a, Task b) => b.updatedAt.compareTo(a.updatedAt);
    int byPriority(Task a, Task b) => b.priority.code - a.priority.code;

    final int Function(Task, Task) compare = switch (sort) {
      TaskSort.dueDate => (a, b) {
          final c = byDue(a, b);
          return c != 0 ? c : byPriority(a, b);
        },
      TaskSort.priority => (a, b) {
          final c = byPriority(a, b);
          return c != 0 ? c : byDue(a, b);
        },
      TaskSort.recent => byRecent,
      // Done last, then overdue, then by due date, then priority, then recency.
      TaskSort.smart => (a, b) {
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
          final c = byDue(a, b);
          if (c != 0) return c;
          final p = byPriority(a, b);
          return p != 0 ? p : byRecent(a, b);
        },
    };
    list.sort(compare);
    return list;
  }

  // ---- preferences ---------------------------------------------------------

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!_themeChosen) {
        themeMode = ThemeMode.values[p.getInt('themeMode') ?? 0];
      }
      sort = TaskSort.values[p.getInt('sort') ?? 0];
      notifyListeners();
    } catch (_) {
      // Preferences are a convenience; defaults are fine.
    }
  }

  bool _themeChosen = false;

  Future<void> setThemeMode(ThemeMode m) async {
    _themeChosen = true;
    themeMode = m;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setInt('themeMode', m.index);
    } catch (_) {}
  }

  Future<void> setSort(TaskSort s) async {
    sort = s;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setInt('sort', s.index);
    } catch (_) {}
  }

  void clearImportNotice() => lastImportCount = null;

  /// The browser's time zone, if it can be detected.
  String? get detectedTimezone => detectTimezone();

  Future<void> _loadSettings(TaskRepository repo) async {
    var s = await repo.loadSettings();
    if (!identical(_repo, repo)) return;
    // Fill in the time zone the first time we see this account, so the
    // morning email lands at the right local hour.
    final tz = detectTimezone();
    if (s.timezone.isEmpty && tz != null) {
      s = s.copyWith(timezone: tz);
      await repo.saveSettings(s);
    }
    settings = s;
    notifyListeners();
    _scheduleReplan();
  }

  /// Reschedules the phone's reminders shortly after a settings change, so
  /// flicking through the dropdowns only reschedules once.
  void _scheduleReplan() {
    if (!reminders.supported) return;
    _replanTimer?.cancel();
    _replanTimer = Timer(const Duration(seconds: 2), replanReminders);
  }

  /// Replaces the scheduled reminders (or clears them when turned off).
  Future<void> replanReminders() async {
    if (!reminders.supported) return;
    try {
      if (user == null || !settings.pushReminders) {
        await reminders.cancelAll();
      } else {
        await reminders.schedule(dailyReminders(settings));
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  /// Turns reminders on: asks for permission, then schedules them.
  /// Returns an error message to show, or null on success.
  Future<String?> enablePushReminders() async {
    if (!reminders.supported) return 'Reminders are only available on iPhone.';
    if (!await reminders.requestPermission()) {
      return 'Notifications are off for Task Tracker. Turn them on in '
          'Settings > Notifications > Task Tracker, then try again.';
    }
    await saveSettings(settings.copyWith(pushReminders: true));
    await replanReminders();
    return null;
  }

  Future<void> disablePushReminders() async {
    await saveSettings(settings.copyWith(pushReminders: false));
    await replanReminders();
  }

  /// Signs out and clears this phone's reminders so the next person to use
  /// it doesn't get them.
  Future<void> signOut() async {
    _replanTimer?.cancel();
    try {
      await reminders.cancelAll();
    } catch (_) {}
    await auth.signOut();
  }

  Future<void> saveSettings(UserSettings s) async {
    settings = s;
    notifyListeners();
    _scheduleReplan();
    await _repo?.saveSettings(s);
  }

  /// Permanently deletes the signed-in user's data and account.
  /// Confirms identity first so nothing is removed if that fails.
  Future<void> deleteAccount({String? password}) async {
    await auth.reauthenticate(password: password);
    await _taskSub?.cancel();
    _taskSub = null;
    await _repo?.deleteAllData();
    await auth.deleteAccount();
  }

  bool _disposed = false;

  // Async work (e.g. the auth listener after sign-out) can finish after the
  // controller is gone; ignore those late updates.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _replanTimer?.cancel();
    _authSub?.cancel();
    _taskSub?.cancel();
    super.dispose();
  }
}

/// Makes the [AppController] available to every screen.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
      : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
