import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/api_client.dart';

const jobColorPalette = [
  Color(0xFF6C63FF),
  Color(0xFFFF9F43),
  Color(0xFF2ECC71),
  Color(0xFF3498DB),
  Color(0xFFE84393),
  Color(0xFF1ABC9C),
];

class JobFormScreen extends StatefulWidget {
  const JobFormScreen({super.key});

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final ApiClient _apiClient = ApiClient();
  final _nameController = TextEditingController();
  final _hourlyController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _paydayController = TextEditingController(text: '5');
  final _laborInsuranceController = TextEditingController(text: '0');
  final _healthInsuranceController = TextEditingController(text: '0');

  Color _selectedColor = jobColorPalette.first;
  PayType _payType = PayType.hourly;
  bool _isSaving = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final job = await _apiClient.createJob(
        name: _nameController.text,
        colorHex: colorToHex(_selectedColor),
        payType: _payType,
        hourlyRate: double.tryParse(_hourlyController.text),
        monthlySalary: double.tryParse(_monthlyController.text),
        payday: int.tryParse(_paydayController.text),
        laborInsuranceFee: double.tryParse(_laborInsuranceController.text) ?? 0,
        healthInsuranceFee: double.tryParse(_healthInsuranceController.text) ?? 0,
      );
      if (mounted) Navigator.pop(context, job);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('新增失敗:$e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hourlyController.dispose();
    _monthlyController.dispose();
    _paydayController.dispose();
    _laborInsuranceController.dispose();
    _healthInsuranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增工作')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '公司名稱', prefixIcon: Icon(Icons.store_outlined)),
          ),
          const SizedBox(height: 20),
          const Text('顏色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: jobColorPalette.map((color) {
              final selected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: CircleAvatar(
                  backgroundColor: color,
                  radius: 18,
                  child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('薪資類型'),
          const SizedBox(height: 8),
          SegmentedButton<PayType>(
            segments: const [
              ButtonSegment(value: PayType.hourly, label: Text('時薪')),
              ButtonSegment(value: PayType.monthly, label: Text('月薪')),
            ],
            selected: {_payType},
            onSelectionChanged: (s) => setState(() => _payType = s.first),
          ),
          const SizedBox(height: 16),
          if (_payType == PayType.hourly)
            TextField(
              controller: _hourlyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '時薪金額', prefixText: '\$ '),
            )
          else
            TextField(
              controller: _monthlyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '月薪金額', prefixText: '\$ '),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _paydayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '發薪日(每月幾號)', suffixText: '號'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _laborInsuranceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '勞保自付額', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _healthInsuranceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '健保自付額', prefixText: '\$ '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
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
