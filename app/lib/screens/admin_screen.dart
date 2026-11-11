import 'package:flutter/material.dart';

import '../models/order_item.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';

/// Admin-only, read-only list of every order in the system.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<OrderItem> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await widget.session.api.adminOrders();
      if (mounted) setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('All orders (admin)'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.pink),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.pink,
              child: _orders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text(
                            'No orders yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final o = _orders[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      o.type == 'follow'
                                          ? Icons.person_add
                                          : Icons.favorite,
                                      color: AppTheme.pink,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${o.count} ${o.type == 'follow' ? 'followers' : 'likes'} for @${o.targetHandle}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      o.status,
                                      style: const TextStyle(
                                        color: AppTheme.gold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  o.ownerName ?? 'Unknown user',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (o.ownerEmail != null)
                                  Text(
                                    o.ownerEmail!,
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  'Fulfilled: ${o.fulfilled}/${o.count}  •  Cost: ${o.cost} coins',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                if (o.createdAt != null)
                                  Text(
                                    o.createdAt!
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first,
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
