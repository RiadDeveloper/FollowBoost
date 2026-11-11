import 'package:flutter/material.dart';

import '../models/order_item.dart';
import '../services/api_client.dart';
import '../services/pricing.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/gradient_button.dart';

/// Orders tab: spend coins on followers/likes + my orders list.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.session});

  final SessionService session;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _type = 'follow';
  final _handleController = TextEditingController();
  double _count = 50;
  List<OrderItem> _orders = [];
  bool _loading = true;
  bool _submitting = false;

  int get _cost => Pricing.orderCost(_type, _count.round());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final orders = await widget.session.api.orders();
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

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await widget.session.api.createOrder(
        type: _type,
        targetHandle: _handleController.text.trim(),
        count: _count.round(),
      );
      widget.session.updateBalance(result.newBalance);
      _handleController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order placed! ${result.order.count} ${_type == 'follow' ? 'followers' : 'likes'} for @${result.order.targetHandle}',
            ),
          ),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.session.user.value?.coins ?? 0;
    return Scaffold(
      appBar: gradientAppBar('Get followers'),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.pink),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'New order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Balance: $balance coins',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'follow',
                              label: Text('Followers'),
                              icon: Icon(Icons.person_add),
                            ),
                            ButtonSegment(
                              value: 'like',
                              label: Text('Likes'),
                              icon: Icon(Icons.favorite),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (s) =>
                              setState(() => _type = s.first),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _handleController,
                          decoration: const InputDecoration(
                            hintText: 'Target Instagram handle (e.g. my.page)',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Count'),
                            Text(
                              '${_count.round()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _count,
                          min: 10,
                          max: 500,
                          divisions: 49,
                          activeColor: AppTheme.pink,
                          label: '${_count.round()}',
                          onChanged: (v) => setState(() => _count = v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _type == 'follow'
                                  ? '2 coins per follower'
                                  : '1 coin per like',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              'Cost: $_cost coins',
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GradientButton(
                          label: 'Place order',
                          isLoading: _submitting,
                          enabled: _cost <= balance,
                          onPressed: _submit,
                        ),
                        if (_cost > balance)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Not enough coins — earn more from tasks or daily rewards.',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'My orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_orders.isEmpty)
                  const Text(
                    'No orders yet.',
                    style: TextStyle(color: AppTheme.textMuted),
                  )
                else
                  ..._orders.map(
                    (o) => Card(
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
                                    ),
                                  ),
                                ),
                                Text(
                                  '-${o.cost}',
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: o.count > 0
                                  ? (o.fulfilled / o.count).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor: Colors.white12,
                              color: AppTheme.pink,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  o.status,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                Text(
                                  '${o.fulfilled}/${o.count} done',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              o.createdAt
                                      ?.toLocal()
                                      .toString()
                                      .split('.')
                                      .first ??
                                  '',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
