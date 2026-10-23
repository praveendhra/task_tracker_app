import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_app/app_controller.dart';
import 'package:task_tracker_app/data/demo_backend.dart';
import 'package:task_tracker_app/models/user_settings.dart';
import 'package:task_tracker_app/models/reminders.dart';
import 'package:task_tracker_app/platform/reminders.dart';
import 'package:task_tracker_app/data/firebase_backend.dart';
import 'package:task_tracker_app/models/task.dart';

void main() {
  group('Task', () {
    Task withSteps(List<TaskStatus> statuses) {
      final t = Task.blank().copyWith(title: 'T', steps: [
        for (var i = 0; i < statuses.length; i++)
          TaskStep(id: 's$i', title: 'Step $i', status: statuses[i]),
      ]);
      return t;
    }

    test('progress follows steps', () {
      final t = withSteps([TaskStatus.done, TaskStatus.notStarted]);
      expect(t.progress, 0.5);
      expect(t.doneSteps, 1);
    });

    test('ticking the last step completes the task, unticking reopens it', () {
      var t = withSteps([TaskStatus.done, TaskStatus.notStarted]);
      t = t.withStep(t.steps[1].copyWith(status: TaskStatus.done));
      expect(t.status, TaskStatus.done);
      expect(t.completedAt, isNotNull);

      t = t.withStep(t.steps[0].copyWith(status: TaskStatus.notStarted));
      expect(t.status, TaskStatus.inProgress);
      expect(t.completedAt, isNull);
    });

    test('current step falls back to the first open step', () {
      final t = withSteps([TaskStatus.done, TaskStatus.inProgress, TaskStatus.notStarted]);
      expect(t.currentStep?.id, 's1');
      expect(t.copyWith(currentStepId: 's2').currentStep?.id, 's2');
    });

    test('overdue only when not done', () {
      final yesterday = TaskDates.today().subtract(const Duration(days: 1));
      final t = Task.blank().copyWith(dueDate: yesterday);
      expect(t.isOverdue, isTrue);
      expect(t.withStatus(TaskStatus.done).isOverdue, isFalse);
    });

    test('step due date round-trips as a plain date', () {
      final s = TaskStep(id: 'a', title: 'x', dueDate: DateTime(2026, 10, 16, 15, 30));
      final m = s.toMap();
      expect(m['dueDate'], '2026-10-16');
      expect(TaskStep.fromMap(m).dueDate, DateTime(2026, 10, 16));
      expect(TaskStep.fromMap({'id': 'b', 'title': 'y'}).dueDate, isNull);
      expect(s.copyWith(clearDueDate: true).dueDate, isNull);
    });

    test('overdue steps are flagged on the task', () {
      final yesterday = TaskDates.today().subtract(const Duration(days: 1));
      final t = Task.blank().copyWith(steps: [
        TaskStep(id: 'a', title: 'late', dueDate: yesterday),
        TaskStep(id: 'b', title: 'done late', dueDate: yesterday, status: TaskStatus.done),
      ]);
      expect(t.hasOverdueStep, isTrue);
      expect(t.datedOpenSteps.map((s) => s.id), ['a']);
    });

    test('step round-trips through a map', () {
      const s = TaskStep(id: 'a', title: 'Do it', note: 'n', status: TaskStatus.inProgress);
      final back = TaskStep.fromMap(s.toMap());
      expect(back.id, 'a');
      expect(back.title, 'Do it');
      expect(back.note, 'n');
      expect(back.status, TaskStatus.inProgress);
    });
  });

  group('legacy import', () {
    test('maps the original JSON format', () {
      final legacy = jsonDecode('''
        {"task_name":"First Task","description":"Look at it","current_step":2,
         "status":2,"archived":false,"id":"abc-123",
         "steps":[
           {"no":1,"content":"One","comment":"c1","status":3},
           {"no":2,"content":"Two","comment":"c2","status":2},
           {"no":3,"content":"Three","comment":"c3","status":1}]}
      ''') as Map<String, dynamic>;
      final t = legacyToTask(legacy);
      expect(t.id, 'abc-123');
      expect(t.title, 'First Task');
      expect(t.status, TaskStatus.inProgress);
      expect(t.steps.length, 3);
      expect(t.steps.first.note, 'c1');
      expect(t.steps.first.status, TaskStatus.done);
      expect(t.currentStep?.title, 'Two');
    });

    test('tolerates missing fields', () {
      final t = legacyToTask({'task_name': 'Bare', 'steps': []});
      expect(t.title, 'Bare');
      expect(t.steps, isEmpty);
      expect(t.id, isNotEmpty);
    });
  });

  group('AppController', () {
    test('filters, search and status cycling on demo data', () async {
      final app = AppController(
        auth: DemoAuthService(),
        repositoryFor: (_) => DemoTaskRepository(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(app.tasksLoaded, isTrue);
      expect(app.archivedTasks.length, 1);
      expect(app.filtered(TaskFilter.done).every((t) => t.isDone), isTrue);
      expect(app.search('contractor').map((t) => t.id), contains('migrate'));

      final sql = app.taskById('sql')!;
      await app.cycleStatus(sql);
      expect(app.taskById('sql')!.isDone, isTrue);
      expect(app.taskById('sql')!.steps.every((s) => s.isDone), isTrue);
      app.dispose();
    });
  });

  group('Reminders', () {
    test('settings round-trip with defaults and clamping', () {
      expect(UserSettings.fromMap(null).pushReminders, isFalse);
      final d = UserSettings.fromMap({});
      expect([d.pushEvery, d.pushFrom, d.pushTo], [1, 9, 21]);
      final s = UserSettings.fromMap({'pushReminders': true, 'pushEvery': 99, 'pushFrom': -3, 'pushTo': 40});
      expect([s.pushReminders, s.pushEvery, s.pushFrom, s.pushTo], [true, 12, 0, 23]);
      expect(UserSettings.fromMap(s.copyWith(pushEvery: 3).toMap()).pushEvery, 3);
    });

    final now = DateTime(2026, 10, 23, 8, 30);
    Task task(String title, {DateTime? due, Priority p = Priority.none, TaskStatus status = TaskStatus.notStarted, List<TaskStep> steps = const []}) =>
        Task(id: title, title: title, dueDate: due, priority: p, status: status, steps: steps, createdAt: now, updatedAt: now);
    const on = UserSettings(pushReminders: true);

    test('hourly from 9 AM to 9 PM by default, starting the next hour', () {
      final r = planReminders([task('Read')], on, now, days: 1);
      expect(r.first.when, DateTime(2026, 10, 23, 9));
      expect(r.where((x) => x.when.day == 23).map((x) => x.when.hour), [for (var h = 9; h <= 21; h++) h]);
    });

    test('every N hours, windows across midnight, max pending', () {
      final every3 = planReminders([task('Read')], on.copyWith(pushEvery: 3, pushFrom: 8, pushTo: 20), now, days: 1);
      expect(every3.where((x) => x.when.day == 23).map((x) => x.when.hour), [11, 14, 17, 20]);
      final night = planReminders([task('Read')], on.copyWith(pushFrom: 22, pushTo: 1), now, days: 1);
      expect(night.map((x) => x.when.hour).take(4), [22, 23, 0, 1]);
      expect(planReminders([task('Read')], on, now).length, 60);
    });

    test('nothing when off or nothing open', () {
      expect(planReminders([task('Read')], const UserSettings(), now), isEmpty);
      expect(planReminders([task('Done', status: TaskStatus.done)], on, now), isEmpty);
    });

    test('text leads with what is due and the next step, per day', () {
      final tasks = [
        task('Quarterly report', due: DateTime(2026, 10, 23), p: Priority.medium, status: TaskStatus.inProgress,
            steps: const [TaskStep(id: 'a', title: 'Pull numbers', status: TaskStatus.done), TaskStep(id: 'b', title: 'Draft slides')]),
        task('Groceries'),
      ];
      expect(reminderText(tasks, DateTime(2026, 10, 23)),
          ('1 due today', 'Next: Draft slides (Quarterly report) · 2 tasks open'));
      expect(reminderText(tasks, DateTime(2026, 10, 24))!.$1, '1 overdue');
      expect(reminderText([task('Read')], DateTime(2026, 10, 23)), ('1 task open', 'Next: Read'));
    });

    test('controller schedules on enable, clears on disable and sign-out; respects a declined prompt', () async {
      final fake = FakeReminderScheduler();
      final app = AppController(auth: DemoAuthService(), repositoryFor: (_) => DemoTaskRepository(), reminders: fake);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await app.enablePushReminders(), isNull);
      expect(app.settings.pushReminders, isTrue);
      expect(fake.scheduled, isNotEmpty);
      await app.disablePushReminders();
      expect(fake.scheduled, isEmpty);
      await app.enablePushReminders();
      await app.signOut();
      expect(fake.scheduled, isEmpty);
      app.dispose();

      final denied = AppController(auth: DemoAuthService(), repositoryFor: (_) => DemoTaskRepository(),
          reminders: FakeReminderScheduler(grant: false));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await denied.saveSettings(denied.settings.copyWith(pushReminders: false));
      expect(await denied.enablePushReminders(), contains('Notifications are off'));
      expect(denied.settings.pushReminders, isFalse);
      denied.dispose();
    });
  });
}
