import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';
import 'models/kanban_task.dart';

/// The state of the Kanban board.
class KanbanState {
  /// Tasks organized by status column.
  final Map<String, List<KanbanTask>> columns;

  /// Whether a server fetch is in progress.
  final bool isLoading;

  /// Last error message, if any.
  final String? error;

  const KanbanState({
    this.columns = const {
      'pending': [],
      'in_progress': [],
      'completed': [],
      'failed': [],
    },
    this.isLoading = false,
    this.error,
  });

  KanbanState copyWith({
    Map<String, List<KanbanTask>>? columns,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return KanbanState(
      columns: columns ?? this.columns,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier that manages Kanban tasks with full CRUD and server sync.
class KanbanNotifier extends StateNotifier<KanbanState> {
  // ignore: unused_field
  final Ref _ref;

  KanbanNotifier(this._ref) : super(KanbanState());

  /// Adds a [task] to the appropriate status column.
  void addTask(KanbanTask task) {
    final status = task.status;
    final column = List<KanbanTask>.from(state.columns[status] ?? []);
    column.add(task);
    state = state.copyWith(
      columns: {...state.columns, status: column},
    );
  }

  /// Moves a task from its current column to [newStatus].
  ///
  /// Does nothing if [taskId] is not found.
  void moveTask(String taskId, String newStatus) {
    KanbanTask? foundTask;
    final newColumns = <String, List<KanbanTask>>{};

    for (final entry in state.columns.entries) {
      final tasks = List<KanbanTask>.from(entry.value);
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        foundTask = tasks.removeAt(index);
      }
      newColumns[entry.key] = tasks;
    }

    if (foundTask == null) return;

    final updatedTask = foundTask.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    final targetColumn = List<KanbanTask>.from(newColumns[newStatus] ?? []);
    targetColumn.add(updatedTask);
    newColumns[newStatus] = targetColumn;

    state = state.copyWith(columns: newColumns);
  }

  /// Removes a task by [taskId] from any column.
  void removeTask(String taskId) {
    final newColumns = <String, List<KanbanTask>>{};
    for (final entry in state.columns.entries) {
      newColumns[entry.key] =
          entry.value.where((t) => t.id != taskId).toList();
    }
    state = state.copyWith(columns: newColumns);
  }

  /// Replaces an existing task with [updated].
  ///
  /// Does nothing if [taskId] does not exist.
  void updateTask(String taskId, KanbanTask updated) {
    final newColumns = <String, List<KanbanTask>>{};
    for (final entry in state.columns.entries) {
      newColumns[entry.key] = entry.value.map((t) {
        if (t.id == taskId) return updated;
        return t;
      }).toList();
    }
    state = state.copyWith(columns: newColumns);
  }

  /// Fetches runs from the Hermes server and populates the board.
  ///
  /// Uses [config] to connect. Each run is converted to a [KanbanTask] and
  /// sorted into its status column. Unknown statuses fall into 'pending'.
  Future<void> loadTasksFromServer(ServerConfig config) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = HermesClient();
      final runs = await client.listRuns(config);
      final tasks = runs.map((run) => KanbanTask.fromJson(run)).toList();

      final columns = <String, List<KanbanTask>>{
        'pending': <KanbanTask>[],
        'in_progress': <KanbanTask>[],
        'completed': <KanbanTask>[],
        'failed': <KanbanTask>[],
      };
      for (final task in tasks) {
        final status = task.status;
        if (columns.containsKey(status)) {
          columns[status]!.add(task);
        } else {
          columns['pending']!.add(task);
        }
      }

      state = state.copyWith(columns: columns, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// The global [StateNotifierProvider] for the Kanban board.
final kanbanProvider =
    StateNotifierProvider<KanbanNotifier, KanbanState>((ref) => KanbanNotifier(ref));
