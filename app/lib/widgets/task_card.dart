import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task_item.dart';
import '../theme.dart';

/// One engagement task: avatar, handle, coin reward, an "Open profile"
/// button (opens Instagram in the external app/browser — never a WebView
/// that could ask for a password) and an "I followed" confirm button.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onConfirm,
    this.confirming = false,
  });

  final TaskItem task;
  final VoidCallback onConfirm;
  final bool confirming;

  Future<void> _openProfile(BuildContext context) async {
    final uri = Uri.parse('https://instagram.com/${task.handle}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Instagram')),
        );
      }
    }
  }

  String _cooldownText(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return 'Available in ${h}h ${m}m';
    }
    return 'Available in ${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final onCooldown = task.isOnCooldown;
    final isFollow = task.type == 'follow';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.avatarColor(task.avatarColor),
              child: Text(
                task.displayName.isNotEmpty
                    ? task.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '@${task.handle}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  if (task.isOrderTask) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.violet),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Order task',
                        style: TextStyle(
                          color: AppTheme.violet,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isFollow ? Icons.person_add : Icons.favorite,
                        size: 14,
                        color: AppTheme.pink,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFollow ? 'Follow' : 'Like',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.monetization_on,
                        size: 14,
                        color: AppTheme.gold,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '+${task.coins} coins',
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (onCooldown && task.cooldownRemaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _cooldownText(task.cooldownRemaining!),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _openProfile(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.violet),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  child: const Text('Open profile'),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: onCooldown || confirming ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: confirming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isFollow ? 'I followed' : 'I liked it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
