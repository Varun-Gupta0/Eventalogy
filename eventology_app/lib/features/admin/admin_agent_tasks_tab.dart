import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_tasks_model.dart';
import '../../services/firestore/agent_tasks_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AdminAgentTasksTab extends StatefulWidget {
  const AdminAgentTasksTab({super.key});

  @override
  State<AdminAgentTasksTab> createState() => _AdminAgentTasksTabState();
}

class _AdminAgentTasksTabState extends State<AdminAgentTasksTab> {
  String _searchQuery = '';
  String _agentFilter = 'All';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<AgentTaskModel>>(
            stream: AgentTasksRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;
              items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                items = items.where((i) =>
                  i.taskId.toLowerCase().contains(q) ||
                  i.eventId.toLowerCase().contains(q) ||
                  i.taskType.toLowerCase().contains(q)).toList();
              }

              if (_agentFilter != 'All') {
                items = items.where((i) => i.agentType == _agentFilter).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status == _statusFilter).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No agent tasks found.'));

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
                hintText: 'Search by Task ID, Event ID, or Type...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _agentFilter,
            items: ['All', 'vendor_discovery', 'negotiator', 'planner']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Agents' : e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _agentFilter = val!),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'pending_approval', 'running', 'completed', 'failed', 'rejected']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Statuses' : e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AgentTaskModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ExpansionTile(
        title: Text('Task: ${item.taskId} | Status: ${item.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Event: ${item.eventId} | Agent: ${item.agentType.toUpperCase()} | Type: ${item.taskType}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.requiresApproval && item.status == 'pending_approval')
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: const Text('⚠️ This task requires manual admin approval before execution.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 8),
                const Text('Input:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildJsonBox(item.input),
                const SizedBox(height: 8),
                const Text('Output:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildJsonBox(item.output ?? 'Pending/None'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Created: ${DateFormat.yMd().add_Hm().format(item.createdAt.toDate())}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (item.requiresApproval && item.status == 'pending_approval')
                      Row(
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => _updateApprovalStatus(item, 'rejected'),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _updateApprovalStatus(item, 'approved'),
                            child: const Text('Approve'),
                          ),
                        ],
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
        data is String ? data : const JsonEncoder.withIndent('  ').convert(data),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  void _updateApprovalStatus(AgentTaskModel item, String newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus == 'approved' ? 'Approve' : 'Reject'} Task'),
        content: Text('Are you sure you want to $newStatus this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              // This is control layer only. Approval triggers no direct AI execution yet.
              final updated = item.copyWith(status: newStatus, approvedBy: 'admin'); // Hardcoded admin for now, ideally fetched from auth
              AgentTasksRepository.update(updated);
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

