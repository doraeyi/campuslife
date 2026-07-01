import 'package:flutter/material.dart';

import '../models/income.dart';
import '../services/api_client.dart';

class IncomeTab extends StatefulWidget {
  const IncomeTab({super.key});

  @override
  State<IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<IncomeTab> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Income>> _incomesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _incomesFuture = _apiClient.fetchIncomes();
    });
  }

  Future<void> _delete(int id) async {
    await _apiClient.deleteIncome(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('對帳')),
      body: FutureBuilder<List<Income>>(
        future: _incomesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final incomes = snapshot.data ?? [];
          if (incomes.isEmpty) {
            return const Center(child: Text('還沒有收入紀錄,去班表頁把這個月的薪資加進來吧'));
          }

          double totalNet = 0;
          for (final income in incomes) {
            totalNet += income.netAmount;
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('累計實領', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          '\$${totalNet.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...incomes.map((income) => Dismissible(
                      key: ValueKey(income.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(income.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Theme.of(context).colorScheme.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                income.job?.color ?? Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.work, size: 16, color: Colors.white),
                          ),
                          title: Text('${income.month}・${income.job?.name ?? '無工作'}'),
                          subtitle: Text('應領 \$${income.grossAmount.toStringAsFixed(0)}'
                              '・扣 \$${income.deductionAmount.toStringAsFixed(0)}'),
                          trailing: Text(
                            '\$${income.netAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}
