import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/allocations_model.dart';
import '../../services/firestore/allocations_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import 'package:intl/intl.dart';

class AdminAllocationsTab extends StatefulWidget {
  const AdminAllocationsTab({super.key});

  @override
  State<AdminAllocationsTab> createState() => _AdminAllocationsTabState();
}

class _AdminAllocationsTabState extends State<AdminAllocationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<AllocationModel>>(
            stream: AllocationsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.allocationId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.eventId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No allocations found.'));

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
                hintText: 'Search by Allocation ID or Event ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'pending', 'assigned', 'confirmed', 'completed', 'cancelled']
                .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Allocation', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AllocationModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text('Allocation ID: ${item.allocationId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${item.eventId} | Assigned By: ${item.assignedBy}'),
            Text('Vendor: ${item.vendorId ?? "None"} | Venue: ${item.venueId ?? "None"} | Service: ${item.serviceId ?? "None"}'),
            Text('Start: ${DateFormat.yMd().add_Hm().format(item.startTime.toDate())} | End: ${DateFormat.yMd().add_Hm().format(item.endTime.toDate())}'),
            Text('Status: ${item.status.toUpperCase()}'),
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
              onPressed: () => _confirmDelete(item.allocationId),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Allocation'),
        content: const Text('Are you sure you want to delete this allocation? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AllocationsRepository.delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDialog(AllocationModel? item) {
    showDialog(
      context: context,
      builder: (context) => _AllocationFormDialog(item: item),
    );
  }
}

class _AllocationFormDialog extends StatefulWidget {
  final AllocationModel? item;
  const _AllocationFormDialog({this.item});

  @override
  State<_AllocationFormDialog> createState() => _AllocationFormDialogState();
}

class _AllocationFormDialogState extends State<_AllocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _assignedByCtrl = TextEditingController();

  String? _selectedEvent;
  String? _selectedVendor;
  String? _selectedVenue;
  String? _selectedService;
  
  String _status = 'pending';
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _venues = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _assignedByCtrl.text = widget.item!.assignedBy;
      _status = widget.item!.status;
      _startTime = widget.item!.startTime.toDate();
      _endTime = widget.item!.endTime.toDate();
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

      final venueSnap = await db.collection(Collections.venues).get();
      _venues = venueSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}).toList();

      final srvSnap = await db.collection(Collections.services).get();
      _services = srvSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}).toList();

      if (widget.item != null) {
        if (_events.any((e) => e['id'] == widget.item!.eventId)) _selectedEvent = widget.item!.eventId;
        if (widget.item!.vendorId != null && _vendors.any((e) => e['id'] == widget.item!.vendorId)) _selectedVendor = widget.item!.vendorId;
        if (widget.item!.venueId != null && _venues.any((e) => e['id'] == widget.item!.venueId)) _selectedVenue = widget.item!.venueId;
        if (widget.item!.serviceId != null && _services.any((e) => e['id'] == widget.item!.serviceId)) _selectedService = widget.item!.serviceId;
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
      title: Text(widget.item == null ? 'New Allocation' : 'Edit Allocation'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedEvent,
                decoration: const InputDecoration(labelText: 'Event'),
                items: _events.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedEvent = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedVendor,
                decoration: const InputDecoration(labelText: 'Vendor (Optional)'),
                items: _vendors.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedVendor = v),
              ),
              DropdownButtonFormField<String>(
                value: _selectedVenue,
                decoration: const InputDecoration(labelText: 'Venue (Optional)'),
                items: _venues.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedVenue = v),
              ),
              DropdownButtonFormField<String>(
                value: _selectedService,
                decoration: const InputDecoration(labelText: 'Service (Optional)'),
                items: _services.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedService = v),
              ),
              TextFormField(
                controller: _assignedByCtrl,
                decoration: const InputDecoration(labelText: 'Assigned By (User ID)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Time'),
                subtitle: Text(DateFormat.yMd().add_Hm().format(_startTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _startTime, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (date != null && mounted) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startTime));
                    if (time != null) setState(() => _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Time'),
                subtitle: Text(DateFormat.yMd().add_Hm().format(_endTime)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: _endTime, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (date != null && mounted) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endTime));
                    if (time != null) setState(() => _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  }
                },
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['pending', 'assigned', 'confirmed', 'completed', 'cancelled']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
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
    
    if (_selectedVendor == null && _selectedVenue == null && _selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one resource (Vendor, Venue, or Service) must be assigned.')));
      return;
    }
    if (_endTime.isBefore(_startTime) || _endTime.isAtSameMomentAs(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End Time must be after Start Time.')));
      return;
    }

    final item = AllocationModel(
      allocationId: widget.item?.allocationId ?? '',
      eventId: _selectedEvent!,
      vendorId: _selectedVendor,
      venueId: _selectedVenue,
      serviceId: _selectedService,
      assignedBy: _assignedByCtrl.text.trim(),
      status: _status,
      startTime: Timestamp.fromDate(_startTime),
      endTime: Timestamp.fromDate(_endTime),
      createdAt: widget.item?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.item == null) {
        await AllocationsRepository.create(item);
      } else {
        await AllocationsRepository.update(item);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

