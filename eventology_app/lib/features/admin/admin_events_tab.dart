import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/events_model.dart';
import '../../services/firestore/events_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import 'package:intl/intl.dart';
import '../../services/admin_api_service.dart';

class AdminEventsTab extends StatefulWidget {
  const AdminEventsTab({super.key});

  @override
  State<AdminEventsTab> createState() => _AdminEventsTabState();
}

class _AdminEventsTabState extends State<AdminEventsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<EventModel>>(
            stream: EventsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.eventId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No events found.'));

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
                hintText: 'Search by title or ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'Draft', 'Planning', 'Confirmed', 'Completed', 'Cancelled']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Event', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(EventModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${item.eventId} | Customer: ${item.customerId}'),
            Text('Date: ${DateFormat.yMMMd().format(item.eventDate.toDate())} | Status: ${item.status.toUpperCase()}'),
            if (item.paymentStatus != null) Text('Payment: ${item.paymentStatus}'),
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
              icon: const Icon(Icons.cancel, color: Colors.redAccent),
              tooltip: 'Cancel Event',
              onPressed: () async {
                try {
                  await AdminApiService.cancelEvent(item.eventId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(EventModel? item) {
    showDialog(
      context: context,
      builder: (context) => _EventFormDialog(item: item),
    );
  }
}

class _EventFormDialog extends StatefulWidget {
  final EventModel? item;
  const _EventFormDialog({this.item});

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _guestCountCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _reqsCtrl = TextEditingController();

  String? _selectedEventType;
  String? _selectedLocation;
  String? _selectedVenue;
  String _status = 'draft';
  String? _paymentStatus;
  DateTime _eventDate = DateTime.now();

  List<Map<String, dynamic>> _eventTypes = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _venues = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleCtrl.text = widget.item!.title;
      _customerCtrl.text = widget.item!.customerId;
      _guestCountCtrl.text = widget.item!.guestCount?.toString() ?? '';
      _budgetCtrl.text = widget.item!.budget?.toString() ?? '';
      _reqsCtrl.text = widget.item!.requirements?['notes'] ?? '';
      _status = widget.item!.status;
      _paymentStatus = widget.item!.paymentStatus;
      _eventDate = widget.item!.eventDate.toDate();
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final db = FirestoreConfig.instance;
      
      final etSnap = await db.collection(Collections.eventTypes).get();
      _eventTypes = etSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

      final locSnap = await db.collection(Collections.locations).get();
      _locations = locSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

      final venSnap = await db.collection(Collections.venues).get();
      _venues = venSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

      if (widget.item != null) {
        if (_eventTypes.any((e) => e['id'] == widget.item!.eventTypeId)) {
          _selectedEventType = widget.item!.eventTypeId;
        }
        if (widget.item!.locationId != null && _locations.any((e) => e['id'] == widget.item!.locationId)) {
          _selectedLocation = widget.item!.locationId;
        }
        if (widget.item!.venueId != null && _venues.any((e) => e['id'] == widget.item!.venueId)) {
          _selectedVenue = widget.item!.venueId;
        }
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
      title: Text(widget.item == null ? 'New Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Event Title'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _customerCtrl,
                decoration: const InputDecoration(labelText: 'Customer ID (User ID)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                decoration: const InputDecoration(labelText: 'Event Type'),
                items: _eventTypes.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedEventType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Event Date'),
                subtitle: Text(DateFormat.yMMMd().format(_eventDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _eventDate = picked);
                },
              ),
              TextFormField(
                controller: _guestCountCtrl,
                decoration: const InputDecoration(labelText: 'Guest Count (Optional)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) return 'Must be a valid integer';
                  return null;
                },
              ),
              TextFormField(
                controller: _budgetCtrl,
                decoration: const InputDecoration(labelText: 'Budget (Optional)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: const InputDecoration(labelText: 'Location (Optional)'),
                items: _locations.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedLocation = v),
              ),
              DropdownButtonFormField<String>(
                value: _selectedVenue,
                decoration: const InputDecoration(labelText: 'Venue (Optional)'),
                items: _venues.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedVenue = v),
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['draft', 'planning', 'confirmed', 'completed', 'cancelled']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment Status (Optional)'),
                items: ['pending', 'partially_paid', 'paid', 'failed', 'refunded']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _paymentStatus = v),
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

    final item = EventModel(
      eventId: widget.item?.eventId ?? '',
      customerId: _customerCtrl.text.trim(),
      eventTypeId: _selectedEventType!,
      title: _titleCtrl.text.trim(),
      eventDate: Timestamp.fromDate(_eventDate),
      guestCount: _guestCountCtrl.text.trim().isEmpty ? null : int.parse(_guestCountCtrl.text.trim()),
      budget: _budgetCtrl.text.trim().isEmpty ? null : double.parse(_budgetCtrl.text.trim()),
      locationId: _selectedLocation,
      venueId: _selectedVenue,
      requirements: _reqsCtrl.text.trim().isEmpty ? null : {'notes': _reqsCtrl.text.trim()},
      status: _status,
      paymentStatus: _paymentStatus,
      createdAt: widget.item?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.item == null) {
        await EventsRepository.create(item);
      } else {
        await EventsRepository.update(item);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

