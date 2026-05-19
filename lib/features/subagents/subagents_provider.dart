import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';
import 'package:hermes_mobile/features/auth/auth_provider.dart';
import 'package:hermes_mobile/features/subagents/models/subagent_task.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// The state of the subagents feature.
class SubagentsState {
  /// All known tasks (flat list).
  final List<SubagentTask> tasks;

  /// Whether a server fetch is in progress.
  final bool isLoading;

  /// The id of the task currently selected for detail view, or `null`.
  final String? selectedTaskId;

  const SubagentsState({
    this.tasks = const [],
    this.isLoading = false,
    this.selectedTaskId,
  });

  SubagentsState copyWith({
    List<SubagentTask>? tasks,
    bool? isLoading,
    String? selectedTaskId,
    bool clearSelected = false,
  }) {
    return SubagentsState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      selectedTaskId: clearSelected ? null : (selectedTaskId ?? this.selectedTaskId),
    );
  }

  // -----------------------------------------------------------------------
  // Computed helpers
  // -----------------------------------------------------------------------

  /// Tasks in tree order: roots first, then their children recursively.
  List<SubagentTask> buildTree() {
    final byParent = <String?, List<SubagentTask>>{};
    for (final t in tasks) {
      byParent.putIfAbsent(t.parentId, () => []).add(t);
    }

    final result = <SubagentTask>[];
    void traverse(String? parentId) {
      final children = byParent[parentId];
      if (children == null) return;
      // Stable sort so children of a given parent appear in insertion order.
      for (final child in children) {
        result.add(child);
        traverse(child.id);
      }
    }

    traverse(null); // start with root tasks
    return result;
  }

  /// Direct children of a given task id.
  List<SubagentTask> childrenOf(String taskId) {
    return tasks.where((t) => t.parentId == taskId).toList();
  }

  /// Count of tasks in a given status.
  int countWithStatus(String status) =>
      tasks.where((t) => t.status == status).length;

  int get totalCount => tasks.length;
  int get runningCount => countWithStatus('running');
  int get pendingCount => countWithStatus('pending');
  int get completedCount => countWithStatus('completed');
  int get failedCount => countWithStatus('failed');
  int get cancelledCount => countWithStatus('cancelled');
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// [StateNotifier] that manages subagent task state.
class SubagentsNotifier extends StateNotifier<SubagentsState> {
  final Ref _ref;

  SubagentsNotifier(this._ref) : super(const SubagentsState()) {
    // If a server config is available, attempt an initial load.
    _maybeLoadFromServer();
  }

  /// Adds a new [task] to the state.
  void addTask(SubagentTask task) {
    state = state.copyWith(tasks: [...state.tasks, task]);
  }

  /// Updates an existing task identified by [taskId].
  /// If [updates] returns the same instance, no change is made.
  void updateTask(String taskId, SubagentTask Function(SubagentTask) updates) {
    final index = state.tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final updated = updates(state.tasks[index]);
    final newTasks = [...state.tasks];
    newTasks[index] = updated;
    state = state.copyWith(tasks: newTasks);
  }

  /// Removes a task by [taskId].
  void removeTask(String taskId) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
      clearSelected:
          state.selectedTaskId == taskId,
    );
  }

  /// Selects a task for detail view, or `null` to deselect.
  void selectTask(String? taskId) {
    state = state.copyWith(
      selectedTaskId: taskId,
      clearSelected: taskId == null,
    );
  }

  /// Fetches subagent data from the Hermes API.
  ///
  /// The API is expected to expose a `/v1/subagents` endpoint returning a JSON
  /// array of subagent task objects, or a map with a `tasks` key.
  Future<void> loadFromServer(ServerConfig config) async {
    state = state.copyWith(isLoading: true);

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      final url = '${config.baseUrl}/v1/subagents';
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer ${config.apiKey}');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        final List<dynamic> items;
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded['tasks'] is List) {
          items = decoded['tasks'] as List;
        } else if (decoded is Map && decoded['data'] is List) {
          items = decoded['data'] as List;
        } else {
          items = [];
        }

        final tasks = items.map((e) => _parseTask(e)).toList();
        state = state.copyWith(tasks: tasks, isLoading: false);
      } else {
        // Server responded but not with 200 – keep existing tasks.
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      // Network error – keep existing state, just clear loading.
      state = state.copyWith(isLoading: false);
    }
  }

  /// Tries to load from server if a config is available.
  Future<void> _maybeLoadFromServer() async {
    final config = _ref.read(authProvider).config;
    if (config != null) {
      await loadFromServer(config);
    }
  }

  /// Public wrapper: refreshes from server if config is available.
  ///
  /// Safe to call from UI code.
  Future<void> refreshIfNeeded() async {
    await _maybeLoadFromServer();
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  SubagentTask _parseTask(Map<String, dynamic> json) {
    return SubagentTask(
      id: (json['id'] ?? '').toString(),
      parentId: json['parent_id']?.toString(),
      goal: (json['goal'] ?? json['description'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      result: json['result']?.toString(),
      error: json['error']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      sessionId: json['session_id']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final subagentsProvider =
    StateNotifierProvider<SubagentsNotifier, SubagentsState>(
        (ref) => SubagentsNotifier(ref));

/// Convenience provider that gives access to the notifier's methods.
final subagentsNotifierProvider =
    Provider<SubagentsNotifier>((ref) => ref.read(subagentsProvider.notifier));
