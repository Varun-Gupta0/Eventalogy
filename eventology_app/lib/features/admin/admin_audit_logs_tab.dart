import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/audit_logs_model.dart';
import '../../services/firestore/audit_logs_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AdminAuditLogsTab extends StatefulWidget {
  const AdminAuditLogsTab({super.key});

  @override
  State<AdminAuditLogsTab> createState() => _AdminAuditLogsTabState();
}

class _AdminAuditLogsTabState extends State<AdminAuditLogsTab> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  String _resourceFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<AuditLogModel>>(
            stream: AuditLogsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;
              
              // Sort newest first
              items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                items = items.where((i) =>
                  i.actorId.toLowerCase().contains(q) ||
                  i.action.toLowerCase().contains(q) ||
                  i.resourceId.toLowerCase().contains(q)).toList();
              }

              if (_roleFilter != 'All') {
                items = items.where((i) => i.actorRole == _roleFilter).toList();
              }

              if (_resourceFilter != 'All') {
                items = items.where((i) => i.resourceType == _resourceFilter).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No audit logs found.'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildCard(item);
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
                hintText: 'Search Actor, Action, or Resource ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _roleFilter,
            items: ['All', 'admin', 'vendor', 'user', 'system']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Roles' : e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _roleFilter = val!),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _resourceFilter,
            items: ['All', 'users', 'events', 'bookings', 'payments', 'allocations', 'settings']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Resources' : e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _resourceFilter = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AuditLogModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ExpansionTile(
        title: Text('${item.action} on ${item.resourceType}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('By: ${item.actorId} (${item.actorRole}) | Date: ${DateFormat.yMd().add_Hms().format(item.timestamp.toDate())}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Log ID: ${item.logId}'),
                Text('Resource ID: ${item.resourceId}'),
                const SizedBox(height: 8),
                const Text('Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    item.metadata != null ? const JsonEncoder.withIndent('  ').convert(item.metadata) : 'None',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

