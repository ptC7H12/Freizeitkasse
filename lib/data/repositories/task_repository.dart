import 'package:drift/drift.dart';
import '../database/app_database.dart';

class TaskRepository {
  final AppDatabase _database;

  TaskRepository(this._database);

  /// Get all tasks for a specific event
  Stream<List<Task>> watchTasksByEvent(int eventId) {
    return (_database.select(_database.tasks)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
            (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Get a single task by ID
  Future<Task?> getTaskById(int id) async {
    return await (_database.select(_database.tasks)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get all tasks for an event (one-time fetch)
  Future<List<Task>> getTasksByEvent(int eventId) async {
    return await (_database.select(_database.tasks)
          ..where((t) => t.eventId.equals(eventId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
            (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get tasks by status
  Future<List<Task>> getTasksByStatus(int eventId, String status) async {
    return await (_database.select(_database.tasks)
          ..where((t) => t.eventId.equals(eventId) & t.status.equals(status))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
          ]))
        .get();
  }

  /// Get tasks assigned to a participant
  Future<List<Task>> getTasksByParticipant(int participantId) async {
    return await (_database.select(_database.tasks)
          ..where((t) => t.assignedTo.equals(participantId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
          ]))
        .get();
  }

  /// Get overdue tasks
  Future<List<Task>> getOverdueTasks(int eventId) async {
    final now = DateTime.now();
    return await (_database.select(_database.tasks)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.status.equals('pending') &
              t.dueDate.isSmallerThanValue(now))
          ..orderBy([
            (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// Get upcoming tasks (next 7 days)
  Future<List<Task>> getUpcomingTasks(int eventId) async {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    return await (_database.select(_database.tasks)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.status.equals('pending') &
              t.dueDate.isBiggerOrEqualValue(now) &
              t.dueDate.isSmallerOrEqualValue(sevenDaysFromNow))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueDate),
          ]))
        .get();
  }

  /// Create a new task
  Future<int> createTask({
    required int eventId,
    required String title,
    required DateTime dueDate,
    String? description,
    String status = 'pending',
    String priority = 'medium',
    int? assignedTo,
  }) async {
    final companion = TasksCompanion(
      eventId: Value(eventId),
      title: Value(title),
      description: Value(description),
      status: Value(status),
      priority: Value(priority),
      dueDate: Value(dueDate),
      assignedTo: Value(assignedTo),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    return await _database.into(_database.tasks).insert(companion);
  }

  /// Update an existing task
  Future<bool> updateTask({
    required int id,
    String? title,
    String? description,
    String? status,
    String? priority,
    DateTime? dueDate,
    int? assignedTo,
    bool? clearAssignment,
  }) async {
    final existing = await getTaskById(id);
    if (existing == null) {
      return false;
    }

    final companion = TasksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      priority: priority != null ? Value(priority) : const Value.absent(),
      dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
      assignedTo: clearAssignment == true
          ? const Value(null)
          : (assignedTo != null ? Value(assignedTo) : const Value.absent()),
      updatedAt: Value(DateTime.now()),
    );

    return await (_database.update(_database.tasks)
          ..where((t) => t.id.equals(id)))
        .write(companion) >
        0;
  }

  /// Mark manual task as completed (by ID)
  Future<bool> markTaskAsCompleted(int id) async {
    return updateTask(id: id, status: 'completed');
  }

  /// Mark task as in progress
  Future<bool> startTask(int id) async {
    return updateTask(id: id, status: 'in_progress');
  }

  /// Delete a task
  Future<bool> deleteTask(int id) async {
    return await (_database.delete(_database.tasks)
          ..where((t) => t.id.equals(id)))
        .go() >
        0;
  }

  /// Get task statistics
  Future<Map<String, dynamic>> getTaskStatistics(int eventId) async {
    final tasks = await getTasksByEvent(eventId);
    final pending = tasks.where((t) => t.status == 'pending').length;
    final inProgress = tasks.where((t) => t.status == 'in_progress').length;
    final completed = tasks.where((t) => t.status == 'completed').length;
    final overdue = await getOverdueTasks(eventId);

    return {
      'total': tasks.length,
      'pending': pending,
      'inProgress': inProgress,
      'completed': completed,
      'overdue': overdue.length,
      'completionRate': tasks.isEmpty ? 0.0 : (completed / tasks.length) * 100,
    };
  }

  // ============================================================================
  // AUTOMATIC TASK GENERATION METHODS
  // ============================================================================

  /// Get all completed tasks for an event as a Set of (taskType, referenceId) tuples
  Future<Set<CompletedTaskKey>> getCompletedTasksByEvent(int eventId) async {
    final completedTasks = await (_database.select(_database.tasks)
          ..where((t) => t.eventId.equals(eventId) & t.isCompleted.equals(true)))
        .get();

    return completedTasks
        .where((t) => t.taskType != null && t.referenceId != null)
        .map((t) => CompletedTaskKey(t.taskType!, t.referenceId!))
        .toSet();
  }

  /// Check if a task is already completed
  Future<bool> isTaskCompleted(int eventId, String taskType, int referenceId) async {
    final task = await (_database.select(_database.tasks)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.taskType.equals(taskType) &
              t.referenceId.equals(referenceId) &
              t.isCompleted.equals(true)))
        .getSingleOrNull();

    return task != null;
  }

  /// Mark a task as completed (creates or updates task)
  Future<bool> completeTask({
    required int eventId,
    required String taskType,
    required int referenceId,
    String? completionNote,
  }) async {
    // Check if task already exists
    final existing = await (_database.select(_database.tasks)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.taskType.equals(taskType) &
              t.referenceId.equals(referenceId)))
        .getSingleOrNull();

    if (existing != null) {
      // Update existing task
      final companion = TasksCompanion(
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now()),
        completionNote: Value(completionNote),
        updatedAt: Value(DateTime.now()),
      );
      return await (_database.update(_database.tasks)
            ..where((t) => t.id.equals(existing.id)))
          .write(companion) >
          0;
    } else {
      // Create new completed task
      final companion = TasksCompanion(
        eventId: Value(eventId),
        title: const Value('Auto-generated task'),
        taskType: Value(taskType),
        referenceId: Value(referenceId),
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now()),
        completionNote: Value(completionNote),
        status: const Value('completed'),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _database.into(_database.tasks).insert(companion);
      return true;
    }
  }

  /// Mark a task as not completed (uncomplete)
  Future<bool> uncompleteTask({
    required int eventId,
    required String taskType,
    required int referenceId,
  }) async {
    final task = await (_database.select(_database.tasks)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.taskType.equals(taskType) &
              t.referenceId.equals(referenceId)))
        .getSingleOrNull();

    if (task != null) {
      // Delete the task
      return await (_database.delete(_database.tasks)
            ..where((t) => t.id.equals(task.id)))
          .go() >
          0;
    }
    return false;
  }

  /// Get count of overdue auto-generated tasks
  Future<int> getOverdueAutoTasksCount(int eventId) async {
    final now = DateTime.now();
    return await (_database.select(_database.tasks)
          ..where((t) =>
              t.eventId.equals(eventId) &
              t.taskType.isNotNull() &
              t.isCompleted.equals(false) &
              t.dueDate.isSmallerThanValue(now)))
        .get()
        .then((tasks) => tasks.length);
  }
}

/// Helper class for completed task lookup
class CompletedTaskKey {
  final String taskType;
  final int referenceId;

  CompletedTaskKey(this.taskType, this.referenceId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedTaskKey &&
          runtimeType == other.runtimeType &&
          taskType == other.taskType &&
          referenceId == other.referenceId;

  @override
  int get hashCode => taskType.hashCode ^ referenceId.hashCode;
}
