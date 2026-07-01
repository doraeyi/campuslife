import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'job_form_screen.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final ApiClient _apiClient = ApiClient();
  late Future<List<Job>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _refreshJobs();
  }

  void _refreshJobs() {
    setState(() {
      _jobsFuture = _apiClient.fetchJobs();
    });
  }

  Future<void> _deleteJob(int jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除工作'),
        content: const Text('確定要刪除這個工作嗎?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apiClient.deleteJob(jobId);
      _refreshJobs();
    }
  }

  Future<void> _addJob() async {
    final result = await Navigator.push<Job>(
      context,
      MaterialPageRoute(builder: (context) => const JobFormScreen()),
    );
    if (result != null) _refreshJobs();
  }

  Future<void> _editProfile() async {
    final currentUser = ref.read(authProvider).value;
    final controller = TextEditingController(text: currentUser?.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改顯示名稱'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '顯示名稱'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && mounted) {
      await _apiClient.updateProfile(displayName: newName);
      // Reload user from SharedPreferences so authProvider reflects the new name
      ref.invalidate(authProvider);
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (user?.displayName ?? '?')[0].toUpperCase(),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(user?.displayName ?? ''),
            subtitle: Text(user?.email ?? ''),
            trailing: TextButton(onPressed: _editProfile, child: const Text('修改')),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Text('我的工作', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addJob,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增工作'),
                ),
              ],
            ),
          ),
          FutureBuilder<List<Job>>(
            future: _jobsFuture,
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton.icon(
                    onPressed: _addJob,
                    icon: const Icon(Icons.add_business),
                    label: const Text('新增第一個工作'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                );
              }
              return Column(
                children: jobs.map((job) {
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: job.color, radius: 14),
                    title: Text(job.name),
                    subtitle: Text(job.payType == PayType.hourly
                        ? '時薪 \$${job.hourlyRate?.toStringAsFixed(0) ?? '-'}/小時'
                        : '月薪 \$${job.monthlySalary?.toStringAsFixed(0) ?? '-'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteJob(job.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('登出', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
