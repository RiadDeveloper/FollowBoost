import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/staggered_item.dart';
import '../widgets/task_card.dart';

/// Tasks tab: earn coins by following / liking profiles (manually).
/// The list also refreshes itself every 30 seconds while this screen
/// is visible, so new orders from other users show up without a
/// pull-to-refresh.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<TaskItem> _tasks = [];
  bool _loading = true;
  String? _confirmingId;
  Timer? _pollTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _poll(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Silent background refresh for the 30s poll: never overlaps itself
  /// and never pops an error SnackBar — the next poll or a
  /// pull-to-refresh retries.
  Future<void> _poll() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      final tasks = await widget.session.api.tasks();
      if (mounted) setState(() => _tasks = tasks);
    } on ApiException {
      // Ignore; retry on the next tick.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _load() async {
    try {
      final tasks = await widget.session.api.tasks();
      if (mounted) setState(() => _tasks = tasks);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(TaskItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          task.type == 'follow' ? 'Did you follow?' : 'Did you like it?',
        ),
        content: Text(
          'Please confirm you ${task.type == 'follow' ? 'followed' : 'liked'} @${task.handle} on Instagram. '
          'You will earn ${task.coins} coins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Yes, I ${task.type == 'follow' ? 'followed' : 'liked it'}',
              style: const TextStyle(color: AppTheme.pink),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _confirmingId = task.id);
    try {
      final result = await widget.session.api.completeTask(task.id);
      widget.session.updateBalance(result.newBalance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+${result.coins} coins earned!')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _confirmingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('Earn coins'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.pink),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.pink,
              child: _tasks.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'No tasks right now.\nCheck back soon!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => StaggeredItem(
                        index: i,
                        child: TaskCard(
                          task: _tasks[i],
                          confirming: _confirmingId == _tasks[i].id,
                          onConfirm: () => _confirm(_tasks[i]),
                        ),
                      ),
                    ),
            ),
    );
  }
}
