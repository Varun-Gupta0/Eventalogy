import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/settings_model.dart';
import '../../services/firestore/settings_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SettingModel>>(
      stream: SettingsRepository.stream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('No settings found.'));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildCard(item);
          },
        );
      },
    );
  }

  Widget _buildCard(SettingModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text(item.settingId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('Last Updated: ${DateFormat.yMd().add_Hm().format(item.updatedAt.toDate())}'),
        trailing: const Icon(Icons.edit, color: AppColors.primary),
        onTap: () => _showDialog(item),
      ),
    );
  }

  void _showDialog(SettingModel item) {
    showDialog(
      context: context,
      builder: (context) => _SettingsFormDialog(item: item),
    );
  }
}

class _SettingsFormDialog extends StatefulWidget {
  final SettingModel item;
  const _SettingsFormDialog({required this.item});

  @override
  State<_SettingsFormDialog> createState() => _SettingsFormDialogState();
}

class _SettingsFormDialogState extends State<_SettingsFormDialog> {
  final _jsonCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _jsonCtrl.text = const JsonEncoder.withIndent('  ').convert(widget.item.value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Setting: ${widget.item.settingId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Value (JSON):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _jsonCtrl,
              maxLines: 15,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() async {
    Map<String, dynamic> parsedVal;
    try {
      parsedVal = jsonDecode(_jsonCtrl.text);
    } catch (e) {
      setState(() => _error = 'Invalid JSON: $e');
      return;
    }

    final updated = widget.item.copyWith(
      value: parsedVal,
      updatedAt: Timestamp.now(),
    );

    try {
      await SettingsRepository.update(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

