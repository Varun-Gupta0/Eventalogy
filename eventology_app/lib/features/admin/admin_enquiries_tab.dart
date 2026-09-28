import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/enquiries_model.dart';
import '../../services/firestore/enquiries_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import 'package:intl/intl.dart';

class AdminEnquiriesTab extends StatefulWidget {
  const AdminEnquiriesTab({super.key});

  @override
  State<AdminEnquiriesTab> createState() => _AdminEnquiriesTabState();
}

class _AdminEnquiriesTabState extends State<AdminEnquiriesTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<EnquiryModel>>(
            stream: EnquiriesRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.enquiryId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No enquiries found.'));

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
                hintText: 'Search by message or ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'Pending', 'Sent', 'Responded', 'Quoted', 'Accepted', 'Rejected', 'Cancelled']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Enquiry', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(EnquiryModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text('Enquiry ID: ${item.enquiryId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${item.eventId} | Customer: ${item.customerId}'),
            Text('Vendor: ${item.vendorId} | Service: ${item.serviceId}'),
            Text('Date: ${DateFormat.yMMMd().format(item.requestedDate.toDate())} | Status: ${item.status.toUpperCase()}'),
            Text('Message: ${item.message}', maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _showDialog(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => EnquiriesRepository.delete(item.enquiryId),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(EnquiryModel? item) {
    showDialog(
      context: context,
      builder: (context) => _EnquiryFormDialog(item: item),
    );
  }
}

class _EnquiryFormDialog extends StatefulWidget {
  final EnquiryModel? item;
  const _EnquiryFormDialog({this.item});

  @override
  State<_EnquiryFormDialog> createState() => _EnquiryFormDialogState();
}

class _EnquiryFormDialogState extends State<_EnquiryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _reqsCtrl = TextEditingController();

  String? _selectedEvent;
  String? _selectedVendor;
  String? _selectedService;
  String _status = 'pending';
  DateTime _reqDate = DateTime.now();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _customerCtrl.text = widget.item!.customerId;
      _msgCtrl.text = widget.item!.message;
      _reqsCtrl.text = widget.item!.requirements?['notes'] ?? '';
      _status = widget.item!.status;
      _reqDate = widget.item!.requestedDate.toDate();
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final db = FirestoreConfig.instance;
      
      final evSnap = await db.collection(Collections.events).get();
      _events = evSnap.docs.map((d) => {'id': d.id, 'name': d.data()['title'] ?? d.id}).toList();

      final venSnap = await db.collection(Collections.vendors).get();
      _vendors = venSnap.docs.map((d) => {'id': d.id, 'name': d.data()['businessName'] ?? d.id}).toList();

      final srvSnap = await db.collection(Collections.services).get();
      _services = srvSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}).toList();

      if (widget.item != null) {
        if (_events.any((e) => e['id'] == widget.item!.eventId)) _selectedEvent = widget.item!.eventId;
        if (_vendors.any((e) => e['id'] == widget.item!.vendorId)) _selectedVendor = widget.item!.vendorId;
        if (_services.any((e) => e['id'] == widget.item!.serviceId)) _selectedService = widget.item!.serviceId;
      }
    } catch (e) {
      debugPrint("Error fetching master data: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
    }

    return AlertDialog(
      title: Text(widget.item == null ? 'New Enquiry' : 'Edit Enquiry'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _customerCtrl,
                decoration: const InputDecoration(labelText: 'Customer ID (User ID)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedEvent,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _events.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedEvent = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedVendor,
                decoration: const InputDecoration(labelText: 'Vendor'),
                items: _vendors.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedVendor = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedService,
                decoration: const InputDecoration(labelText: 'Service'),
                items: _services.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedService = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requested Date'),
                subtitle: Text(DateFormat.yMMMd().format(_reqDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _reqDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _reqDate = picked);
                },
              ),
              TextFormField(
                controller: _msgCtrl,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['pending', 'sent', 'responded', 'quoted', 'accepted', 'rejected', 'cancelled']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              TextFormField(
                controller: _reqsCtrl,
                decoration: const InputDecoration(labelText: 'Requirements/Notes (Optional)'),
                maxLines: 2,
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

    final item = EnquiryModel(
      enquiryId: widget.item?.enquiryId ?? '',
      eventId: _selectedEvent!,
      customerId: _customerCtrl.text.trim(),
      vendorId: _selectedVendor!,
      serviceId: _selectedService!,
      message: _msgCtrl.text.trim(),
      requirements: _reqsCtrl.text.trim().isEmpty ? null : {'notes': _reqsCtrl.text.trim()},
      requestedDate: Timestamp.fromDate(_reqDate),
      status: _status,
      createdAt: widget.item?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.item == null) {
        await EnquiriesRepository.create(item);
      } else {
        await EnquiriesRepository.update(item);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

