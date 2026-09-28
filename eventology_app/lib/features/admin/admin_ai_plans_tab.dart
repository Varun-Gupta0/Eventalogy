import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_plans_model.dart';
import '../../services/firestore/ai_plans_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AdminAiPlansTab extends StatefulWidget {
  const AdminAiPlansTab({super.key});

  @override
  State<AdminAiPlansTab> createState() => _AdminAiPlansTabState();
}

class _AdminAiPlansTabState extends State<AdminAiPlansTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<AiPlanModel>>(
            stream: AiPlansRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                items = items.where((i) =>
                  i.planId.toLowerCase().contains(q) ||
                  i.eventId.toLowerCase().contains(q) ||
                  i.userId.toLowerCase().contains(q)).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status == _statusFilter).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No AI plans found.'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildCard(items[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search Plan ID, Event ID, or User ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'pending', 'generating', 'completed', 'failed']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Statuses' : e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AiPlanModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ExpansionTile(
        title: Text('Plan: ${item.planId} | Status: ${item.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Event: ${item.eventId} | User: ${item.userId} | Date: ${DateFormat.yMd().add_Hm().format(item.createdAt.toDate())}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Estimated Budget: \$${item.estimatedBudget.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Event Requirements:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildJsonBox(item.eventRequirements),
                const SizedBox(height: 8),
                const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildJsonBox(item.recommendations),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => _confirmDelete(item.planId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonBox(dynamic data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
      child: Text(
        const JsonEncoder.withIndent('  ').convert(data),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI Plan'),
        content: const Text('Are you sure you want to delete this AI plan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AiPlansRepository.delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

