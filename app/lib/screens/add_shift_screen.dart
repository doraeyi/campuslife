import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_client.dart';
import 'job_form_screen.dart';

class _ShiftPreset {
  final String label;
  final TimeOfDay start;
  final TimeOfDay end;

  const _ShiftPreset(this.label, this.start, this.end);
}

const _shiftPresets = [
  _ShiftPreset('早班', TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 16, minute: 0)),
  _ShiftPreset('午班', TimeOfDay(hour: 13, minute: 0), TimeOfDay(hour: 21, minute: 0)),
  _ShiftPreset('晚班', TimeOfDay(hour: 17, minute: 0), TimeOfDay(hour: 22, minute: 0)),
  _ShiftPreset('大夜', TimeOfDay(hour: 22, minute: 0), TimeOfDay(hour: 6, minute: 0)),
];

class AddShiftScreen extends StatefulWidget {
  const AddShiftScreen({super.key});

  @override
  State<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends State<AddShiftScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String? _shiftType;
  bool _isSaving = false;

  late Future<List<Job>> _jobsFuture;
  Job? _selectedJob;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _apiClient.fetchJobs();
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  void _applyPreset(_ShiftPreset preset) {
    setState(() {
      _shiftType = preset.label;
      _startTime = preset.start;
      _endTime = preset.end;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _shiftType = null;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _shiftType = null;
      });
    }
  }

  Future<void> _createJob() async {
    final result = await Navigator.push<Job>(
      context,
      MaterialPageRoute(builder: (context) => const JobFormScreen()),
    );
    if (result != null) {
      setState(() {
        _jobsFuture = _apiClient.fetchJobs();
        _selectedJob = result;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _apiClient.createShift(
        date: _date,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        jobId: _selectedJob?.id,
        shiftType: _shiftType,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增失敗:$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增班表')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('工作', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Job>>(
            future: _jobsFuture,
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? [];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...jobs.map((job) {
                    final selected = _selectedJob?.id == job.id;
                    return ChoiceChip(
                      label: Text(job.name),
                      selected: selected,
                      selectedColor: job.color,
                      labelStyle: TextStyle(color: selected ? Colors.white : null),
                      avatar: CircleAvatar(backgroundColor: job.color, radius: 6),
                      onSelected: (_) => setState(() => _selectedJob = job),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('新增工作'),
                    onPressed: _createJob,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('班別快選', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _shiftPresets.map((preset) {
              return ChoiceChip(
                label: Text(preset.label),
                selected: _shiftType == preset.label,
                onSelected: (_) => _applyPreset(preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('日期'),
                  subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
                  onTap: _pickDate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('上班時間'),
                  subtitle: Text(_startTime.format(context)),
                  onTap: _pickStartTime,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('下班時間'),
                  subtitle: Text(_endTime.format(context)),
                  onTap: _pickEndTime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '備註(選填)',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('儲存'),
          ),
        ],
      ),
    );
  }
}

