import 'dart:math';

/// Where a task (or one of its steps) stands.
///
/// The numeric [code] values match what the original app stored
/// (1 = not started, 2 = active/waiting, 3 = completed) so legacy data maps
/// across without a lookup table.
enum TaskStatus {
  notStarted(1, 'Not started'),
  inProgress(2, 'In progress'),
  done(3, 'Done');

  const TaskStatus(this.code, this.label);
  final int code;
  final String label;

  static TaskStatus fromCode(Object? code) {
    final c = code is num ? code.toInt() : int.tryParse('$code');
    return TaskStatus.values.firstWhere(
      (s) => s.code == c,
      orElse: () => TaskStatus.notStarted,
    );
  }

  TaskStatus get next => switch (this) {
        TaskStatus.notStarted => TaskStatus.inProgress,
        TaskStatus.inProgress => TaskStatus.done,
        TaskStatus.done => TaskStatus.notStarted,
      };
}

enum Priority {
  none(0, 'No priority'),
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'High');

  const Priority(this.code, this.label);
  final int code;
  final String label;

  static Priority fromCode(Object? code) {
    final c = code is num ? code.toInt() : int.tryParse('$code');
    return Priority.values.firstWhere(
      (p) => p.code == c,
      orElse: () => Priority.none,
    );
  }
}

String newId() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random.secure();
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

class TaskStep {
  const TaskStep({
    required this.id,
    required this.title,
    this.note = '',
    this.status = TaskStatus.notStarted,
    this.dueDate,
  });

  final String id;
  final String title;
  final String note;
  final TaskStatus status;

  /// Optional, date only (no time).
  final DateTime? dueDate;

  bool get isDone => status == TaskStatus.done;

  bool get isOverdue =>
      dueDate != null && !isDone && dueDate!.isBefore(TaskDates.today());

  bool get isDueToday =>
      dueDate != null && !isDone && TaskDates.dateOnly(dueDate!) == TaskDates.today();

  TaskStep copyWith({
    String? title,
    String? note,
    TaskStatus? status,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) =>
      TaskStep(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        status: status ?? this.status,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'status': status.code,
        // Stored as "YYYY-MM-DD" so it means the same calendar day everywhere.
        'dueDate': dueDate == null ? null : TaskDates.ymd(dueDate!),
      };

  factory TaskStep.fromMap(Map<String, dynamic> m) => TaskStep(
        id: (m['id'] as String?) ?? newId(),
        title: (m['title'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        status: TaskStatus.fromCode(m['status']),
        dueDate: TaskDates.parseYmd(m['dueDate']),
      );
}

class Task {
  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.notStarted,
    this.priority = Priority.none,
    this.dueDate,
    this.tags = const [],
    this.steps = const [],
    this.currentStepId,
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final Priority priority;
  final DateTime? dueDate;
  final List<String> tags;
  final List<TaskStep> steps;
  final String? currentStepId;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  factory Task.blank() {
    final now = DateTime.now();
    return Task(id: newId(), title: '', createdAt: now, updatedAt: now);
  }

  bool get isDone => status == TaskStatus.done;

  int get doneSteps => steps.where((s) => s.isDone).length;

  /// 0..1. Uses steps when there are any, otherwise the task's own status.
  double get progress {
    if (steps.isEmpty) {
      return switch (status) {
        TaskStatus.done => 1,
        TaskStatus.inProgress => 0.5,
        TaskStatus.notStarted => 0,
      };
    }
    return doneSteps / steps.length;
  }

  TaskStep? get currentStep {
    if (steps.isEmpty) return null;
    for (final s in steps) {
      if (s.id == currentStepId) return s;
    }
    // Fall back to the first step that isn't finished.
    for (final s in steps) {
      if (!s.isDone) return s;
    }
    return null;
  }

  /// Open steps with a date, soonest first.
  List<TaskStep> get datedOpenSteps =>
      steps.where((s) => s.dueDate != null && !s.isDone).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  bool get hasOverdueStep => steps.any((s) => s.isOverdue);

  bool get isOverdue {
    if (dueDate == null || isDone) return false;
    final today = TaskDates.today();
    return dueDate!.isBefore(today);
  }

  bool get isDueSoon {
    if (dueDate == null || isDone) return false;
    final today = TaskDates.today();
    return !dueDate!.isBefore(today) &&
        dueDate!.isBefore(today.add(const Duration(days: 3)));
  }

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    Priority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    List<String>? tags,
    List<TaskStep>? steps,
    String? currentStepId,
    bool clearCurrentStep = false,
    bool? archived,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        tags: tags ?? this.tags,
        steps: steps ?? this.steps,
        currentStepId:
            clearCurrentStep ? null : (currentStepId ?? this.currentStepId),
        archived: archived ?? this.archived,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  /// Sets the status and keeps [completedAt] consistent with it.
  Task withStatus(TaskStatus s) {
    final now = DateTime.now();
    return copyWith(
      status: s,
      completedAt: s == TaskStatus.done ? (completedAt ?? now) : null,
      clearCompletedAt: s != TaskStatus.done,
    );
  }

  /// Updates one step and derives the task status from its steps, so ticking
  /// the last step completes the task and un-ticking re-opens it.
  Task withStep(TaskStep step) {
    final updated = [for (final s in steps) s.id == step.id ? step : s];
    final t = copyWith(steps: updated);
    return t.withStatus(_derivedStatus(updated));
  }

  static TaskStatus _derivedStatus(List<TaskStep> steps) {
    if (steps.isEmpty) return TaskStatus.notStarted;
    if (steps.every((s) => s.isDone)) return TaskStatus.done;
    if (steps.any((s) => s.status != TaskStatus.notStarted)) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.notStarted;
  }

  /// Fields shared by Firestore and the demo store. Timestamps are left to
  /// the repository so Firestore can use server time.
  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'status': status.code,
        'priority': priority.code,
        'tags': tags,
        'steps': steps.map((s) => s.toMap()).toList(),
        'currentStepId': currentStepId,
        'archived': archived,
      };

  /// Text used by search.
  String get searchText => [
        title,
        description,
        ...tags,
        for (final s in steps) ...[s.title, s.note],
      ].join(' ').toLowerCase();
}

/// Small date helpers so the model has no Flutter dependency.
class TaskDates {
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parseYmd(Object? v) {
    if (v is DateTime) return dateOnly(v);
    if (v is! String || v.length < 10) return null;
    final parts = v.substring(0, 10).split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((p) => p == null)) return null;
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }
}
