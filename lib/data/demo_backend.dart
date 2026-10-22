import 'dart:async';

import '../models/task.dart';
import '../models/user_settings.dart';
import 'repository.dart';

/// In-memory backend used when the app is built with
/// `--dart-define=DEMO=true`. No Firebase, no sign-in required: handy for UI
/// work and for the screenshots CI takes on every pull request.
class DemoAuthService implements AuthService {
  DemoAuthService({bool signedIn = true})
      : _user = signedIn ? _demoUser : null;

  static const _demoUser =
      AppUser(uid: 'demo', email: 'demo@task.app', displayName: 'Alex');

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  Stream<AppUser?> get userChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  void _set(AppUser? u) {
    _user = u;
    _controller.add(u);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (password.length < 6) {
      throw const AuthFailure('Email or password is incorrect.');
    }
    _set(AppUser(uid: 'demo', email: email, displayName: 'Alex'));
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _set(_demoUser);
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _set(AppUser(uid: 'demo', email: email, displayName: name));
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updateDisplayName(String name) async {
    final u = _user;
    if (u != null) {
      _set(AppUser(uid: u.uid, email: u.email, displayName: name));
    }
  }

  @override
  Future<void> signOut() async => _set(null);

  @override
  bool get supportsApple => true;

  @override
  Future<void> signInWithApple() async => _set(_demoUser);

  @override
  String? get primaryProvider => 'password';

  @override
  Future<void> reauthenticate({String? password}) async {
    if ((password ?? '').length < 6) {
      throw const AuthFailure('Email or password is incorrect.');
    }
  }

  @override
  Future<void> deleteAccount() async => _set(null);
}

class DemoTaskRepository extends TaskRepository {
  DemoTaskRepository() : _tasks = {for (final t in _seed()) t.id: t};

  final Map<String, Task> _tasks;
  final _controller = StreamController<List<Task>>.broadcast();

  List<Task> get _snapshot => _tasks.values.toList();

  @override
  Stream<List<Task>> watchTasks() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<void> save(Task task) async {
    _tasks[task.id] = task.copyWith(updatedAt: DateTime.now());
    _controller.add(_snapshot);
  }

  UserSettings _settings =
      const UserSettings(dailyEmail: true, timezone: 'America/New_York');

  @override
  Future<UserSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(UserSettings settings) async => _settings = settings;

  @override
  Future<void> deleteAllData() async {
    _tasks.clear();
    _controller.add(_snapshot);
  }

  @override
  Future<void> delete(String taskId) async {
    _tasks.remove(taskId);
    _controller.add(_snapshot);
  }

  static List<Task> _seed() {
    final now = DateTime.now();
    final today = TaskDates.today();
    DateTime ago(int h) => now.subtract(Duration(hours: h));
    TaskStep s(String id, String title, TaskStatus st, [String note = '', int? dueIn]) =>
        TaskStep(
          id: id,
          title: title,
          note: note,
          status: st,
          dueDate: dueIn == null ? null : today.add(Duration(days: dueIn)),
        );
    const d = TaskStatus.done, p = TaskStatus.inProgress, n = TaskStatus.notStarted;

    return [
      Task(
        id: 'migrate',
        title: 'Plan the kitchen renovation',
        description:
            'Get quotes, pick materials and book the contractor before spring.',
        status: p,
        priority: Priority.high,
        dueDate: today.add(const Duration(days: 2)),
        tags: const ['home', 'project'],
        steps: [
          s('m1', 'Measure the space', d, 'Floor plan saved to photos'),
          s('m2', 'Collect three quotes', d, 'Cheapest is not the fastest'),
          s('m3', 'Choose cabinets and countertops', p,
              'Visit showroom Saturday', 1),
          s('m4', 'Book the contractor', n, '', 2),
        ],
        currentStepId: 'm3',
        createdAt: ago(240),
        updatedAt: ago(2),
      ),
      Task(
        id: 'sql',
        title: 'Prepare quarterly report',
        description: 'Numbers, highlights and next quarter goals for the team.',
        status: n,
        priority: Priority.medium,
        dueDate: today.subtract(const Duration(days: 1)),
        tags: const ['work', 'report'],
        steps: [
          s('q1', 'Pull the sales numbers', n, '', -1),
          s('q2', 'Draft the summary slides', n),
          s('q3', 'Review with manager', n),
        ],
        createdAt: ago(100),
        updatedAt: ago(30),
      ),
      Task(
        id: 'portfolio',
        title: 'Refresh portfolio site',
        description: 'New projects section and a lighter theme.',
        status: p,
        priority: Priority.low,
        dueDate: today.add(const Duration(days: 9)),
        tags: const ['personal'],
        steps: [
          s('p1', 'Pick the three projects to feature', d),
          s('p2', 'Write project blurbs', p, 'One done, two to go', 0),
          s('p3', 'Ship it', n),
        ],
        currentStepId: 'p2',
        createdAt: ago(300),
        updatedAt: ago(20),
      ),
      Task(
        id: 'groceries',
        title: 'Weekend groceries',
        status: n,
        tags: const ['home'],
        dueDate: today.add(const Duration(days: 4)),
        steps: [
          s('g1', 'Fruit, bread, eggs', n),
          s('g2', 'Coffee beans', n),
        ],
        createdAt: ago(6),
        updatedAt: ago(6),
      ),
      Task(
        id: 'terraform',
        title: 'Renew passport',
        description: 'Photos, form and appointment.',
        status: d,
        priority: Priority.medium,
        tags: const ['personal'],
        steps: [
          s('t1', 'Take new photos', d),
          s('t2', 'Fill in the form', d),
          s('t3', 'Submit at the post office', d),
        ],
        createdAt: ago(500),
        updatedAt: ago(26),
        completedAt: ago(26),
      ),
      Task(
        id: 'dentist',
        title: 'Book dentist appointment',
        status: d,
        createdAt: ago(200),
        updatedAt: ago(70),
        completedAt: ago(70),
      ),
      Task(
        id: 'old',
        title: 'Spring conference talk proposal',
        status: d,
        archived: true,
        tags: const ['personal'],
        createdAt: ago(2000),
        updatedAt: ago(1500),
        completedAt: ago(1500),
      ),
    ];
  }
}
