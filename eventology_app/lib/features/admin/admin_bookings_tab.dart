import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bookings_model.dart';
import '../../services/firestore/bookings_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import 'package:intl/intl.dart';

class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({super.key});

  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<BookingModel>>(
            stream: BookingsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.customerId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.bookingId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No bookings found.'));

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
                hintText: 'Search by Customer ID or Booking ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'Pending', 'Confirmed', 'Completed', 'Cancelled']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Booking', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BookingModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text('Booking ID: ${item.bookingId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${item.eventId} | Customer: ${item.customerId}'),
            Text('Vendor: ${item.vendorId} | Service: ${item.serviceId}'),
            Text('Date: ${DateFormat.yMMMd().format(item.bookingDate.toDate())} | Amount: ₹${item.amount.toStringAsFixed(2)}'),
            Text('Status: ${item.status.toUpperCase()} | Payment: ${item.paymentStatus.toUpperCase()}'),
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
              onPressed: () => BookingsRepository.delete(item.bookingId),
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BookingModel? item) {
    showDialog(
      context: context,
      builder: (context) => _BookingFormDialog(item: item),
    );
  }
}

class _BookingFormDialog extends StatefulWidget {
  final BookingModel? item;
  const _BookingFormDialog({this.item});

  @override
  State<_BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<_BookingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _selectedEvent;
  String? _selectedVendor;
  String? _selectedService;
  String? _selectedVenue;
  String? _selectedPackage;
  
  String _status = 'pending';
  String _paymentStatus = 'pending';
  DateTime _bookingDate = DateTime.now();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _venues = [];
  List<Map<String, dynamic>> _packages = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _customerCtrl.text = widget.item!.customerId;
      _amountCtrl.text = widget.item!.amount.toString();
      _status = widget.item!.status;
      _paymentStatus = widget.item!.paymentStatus;
      _bookingDate = widget.item!.bookingDate.toDate();
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

      final venueSnap = await db.collection(Collections.venues).get();
      _venues = venueSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}).toList();

      final pkgSnap = await db.collection(Collections.packages).get();
      _packages = pkgSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}).toList();

      if (widget.item != null) {
        if (_events.any((e) => e['id'] == widget.item!.eventId)) _selectedEvent = widget.item!.eventId;
        if (_vendors.any((e) => e['id'] == widget.item!.vendorId)) _selectedVendor = widget.item!.vendorId;
        if (_services.any((e) => e['id'] == widget.item!.serviceId)) _selectedService = widget.item!.serviceId;
        if (widget.item!.venueId != null && _venues.any((e) => e['id'] == widget.item!.venueId)) _selectedVenue = widget.item!.venueId;
        if (widget.item!.packageId != null && _packages.any((e) => e['id'] == widget.item!.packageId)) _selectedPackage = widget.item!.packageId;
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
      title: Text(widget.item == null ? 'New Booking' : 'Edit Booking'),
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
              DropdownButtonFormField<String>(
                value: _selectedVenue,
                decoration: const InputDecoration(labelText: 'Venue (Optional)'),
                items: _venues.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedVenue = v),
              ),
              DropdownButtonFormField<String>(
                value: _selectedPackage,
                decoration: const InputDecoration(labelText: 'Package (Optional)'),
                items: _packages.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedPackage = v),
              ),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Booking Date'),
                subtitle: Text(DateFormat.yMMMd().format(_bookingDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _bookingDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _bookingDate = picked);
                },
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Booking Status'),
                items: ['pending', 'confirmed', 'completed', 'cancelled']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment Status'),
                items: ['pending', 'partially_paid', 'paid', 'failed', 'refunded']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _paymentStatus = v!),
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

    final item = BookingModel(
      bookingId: widget.item?.bookingId ?? '',
      eventId: _selectedEvent!,
      customerId: _customerCtrl.text.trim(),
      vendorId: _selectedVendor!,
      serviceId: _selectedService!,
      venueId: _selectedVenue,
      packageId: _selectedPackage,
      amount: double.parse(_amountCtrl.text.trim()),
      status: _status,
      paymentStatus: _paymentStatus,
      bookingDate: Timestamp.fromDate(_bookingDate),
      createdAt: widget.item?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.item == null) {
        await BookingsRepository.create(item);
      } else {
        await BookingsRepository.update(item);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

