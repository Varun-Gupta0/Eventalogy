import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/notifications_model.dart';
import '../../services/firestore/notifications_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNotificationsTab extends StatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<NotificationModel>>(
            stream: NotificationsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.notificationId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.userId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (_statusFilter != 'All') {
                final isRead = _statusFilter == 'Read';
                items = items.where((i) => i.read == isRead).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No notifications found.'));

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
                hintText: 'Search by User ID, Title, or ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'Read', 'Unread']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Notification', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(NotificationModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text('${item.title} (ID: ${item.notificationId})', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${item.userId} | Event: ${item.eventId ?? "N/A"}'),
            Text('Type: ${item.type.toUpperCase()} | Status: ${item.read ? "Read" : "Unread"}'),
            Text('Date: ${DateFormat.yMd().add_Hm().format(item.createdAt.toDate())}'),
            const SizedBox(height: 4),
            Text('Message: ${item.message}', maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(item.read ? Icons.mark_email_unread : Icons.mark_email_read, color: Colors.blueAccent),
              onPressed: () => _toggleReadStatus(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _confirmDelete(item.notificationId),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleReadStatus(NotificationModel item) {
    final updated = item.copyWith(read: !item.read);
    NotificationsRepository.update(updated);
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              NotificationsRepository.delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDialog(NotificationModel? item) {
    showDialog(
      context: context,
      builder: (context) => _NotificationFormDialog(item: item),
    );
  }
}

class _NotificationFormDialog extends StatefulWidget {
  final NotificationModel? item;
  const _NotificationFormDialog({this.item});

  @override
  State<_NotificationFormDialog> createState() => _NotificationFormDialogState();
}

class _NotificationFormDialogState extends State<_NotificationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _eventCtrl = TextEditingController();
  
  String _type = 'system';
  bool _isRead = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _userCtrl.text = widget.item!.userId;
      _titleCtrl.text = widget.item!.title;
      _msgCtrl.text = widget.item!.message;
      _eventCtrl.text = widget.item!.eventId ?? '';
      _type = widget.item!.type.isEmpty ? 'system' : widget.item!.type;
      _isRead = widget.item!.read;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'New Notification' : 'Edit Notification'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(labelText: 'User ID'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: ['system', 'alert', 'reminder', 'update']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _msgCtrl,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _eventCtrl,
                decoration: const InputDecoration(labelText: 'Event ID (Optional)'),
              ),
              SwitchListTile(
                title: const Text('Read Status'),
                value: _isRead,
                onChanged: (v) => setState(() => _isRead = v),
              ),
            ],
          ),
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
    if (!_formKey.currentState!.validate()) return;

    final item = NotificationModel(
      notificationId: widget.item?.notificationId ?? '',
      userId: _userCtrl.text.trim(),
      type: _type,
      title: _titleCtrl.text.trim(),
      message: _msgCtrl.text.trim(),
      eventId: _eventCtrl.text.trim().isEmpty ? null : _eventCtrl.text.trim(),
      read: _isRead,
      createdAt: widget.item?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.item == null) {
        await NotificationsRepository.create(item);
      } else {
        await NotificationsRepository.update(item);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

