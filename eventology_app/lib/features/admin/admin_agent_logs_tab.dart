import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/agent_logs_model.dart';
import '../../services/firestore/agent_logs_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AdminAgentLogsTab extends StatefulWidget {
  const AdminAgentLogsTab({super.key});

  @override
  State<AdminAgentLogsTab> createState() => _AdminAgentLogsTabState();
}

class _AdminAgentLogsTabState extends State<AdminAgentLogsTab> {
  String _searchQuery = '';
  String _agentFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<AgentLogModel>>(
            stream: AgentLogsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;
              items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                items = items.where((i) =>
                  i.logId.toLowerCase().contains(q) ||
                  i.taskId.toLowerCase().contains(q) ||
                  i.action.toLowerCase().contains(q)).toList();
              }

              if (_agentFilter != 'All') {
                items = items.where((i) => i.agentType == _agentFilter).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No agent logs found.'));

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
                hintText: 'Search by Log ID, Task ID, or Action...',
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
        ],
      ),
    );
  }

  Widget _buildCard(AgentLogModel item) {
    final isError = item.result.toLowerCase() == 'failed' || item.result.toLowerCase() == 'error';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ExpansionTile(
        title: Text('Log: ${item.logId} | Action: ${item.action}', style: TextStyle(fontWeight: FontWeight.bold, color: isError ? Colors.redAccent : null)),
        subtitle: Text('Task: ${item.taskId} | Agent: ${item.agentType.toUpperCase()} | Date: ${DateFormat.yMd().add_Hms().format(item.timestamp.toDate())}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Result: ${item.result}', style: TextStyle(fontWeight: FontWeight.bold, color: isError ? Colors.redAccent : Colors.green)),
                const SizedBox(height: 8),
                const Text('Input:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildJsonBox(item.input),
                const SizedBox(height: 8),
                const Text('Output:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildJsonBox(item.output ?? 'None'),
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
}

