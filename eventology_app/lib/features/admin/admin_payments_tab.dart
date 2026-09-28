import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/payments_model.dart';
import '../../services/firestore/payments_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import 'package:intl/intl.dart';

class AdminPaymentsTab extends StatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  State<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

class _AdminPaymentsTabState extends State<AdminPaymentsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _methodFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<PaymentModel>>(
            stream: PaymentsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.paymentId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.customerId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.transactionId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
              }

              if (_methodFilter != 'All') {
                items = items.where((i) => i.paymentMethod.toLowerCase() == _methodFilter.toLowerCase()).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No payments found.'));

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
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by Payment ID, Customer ID, TXN...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status Filter', border: OutlineInputBorder()),
              items: ['All', 'pending', 'paid', 'failed', 'refunded', 'partially_paid']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _methodFilter,
              decoration: const InputDecoration(labelText: 'Method Filter', border: OutlineInputBorder()),
              items: ['All', 'card', 'bank_transfer', 'cash', 'upi', 'wallet']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (val) => setState(() => _methodFilter = val!),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Payment', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PaymentModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text('Payment ID: ${item.paymentId} | Amount: ${item.currency.toUpperCase()} ${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${item.eventId} | Booking: ${item.bookingId}'),
            Text('Customer: ${item.customerId} | Transaction ID: ${item.transactionId}'),
            Text('Method: ${item.paymentMethod.toUpperCase()} | Status: ${item.status.toUpperCase()}'),
            if (item.paidAt != null) Text('Paid At: ${DateFormat.yMd().add_Hm().format(item.paidAt!.toDate())}'),
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
              onPressed: () => _confirmDelete(item.paymentId),
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
        title: const Text('Delete Payment Record'),
        content: const Text('Are you sure you want to delete this payment record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              PaymentsRepository.delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDialog(PaymentModel? item) {
    showDialog(
      context: context,
      builder: (context) => _PaymentFormDialog(item: item),
    );
  }
}

class _PaymentFormDialog extends StatefulWidget {
  final PaymentModel? item;
  const _PaymentFormDialog({this.item});

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'INR');
  final _transactionCtrl = TextEditingController();

  String? _selectedEvent;
  String? _selectedBooking;
  
  String _status = 'pending';
  String _paymentMethod = 'card';
  DateTime? _paidAt;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _customerCtrl.text = widget.item!.customerId;
      _amountCtrl.text = widget.item!.amount.toString();
      _currencyCtrl.text = widget.item!.currency;
      _transactionCtrl.text = widget.item!.transactionId;
      _status = widget.item!.status;
      _paymentMethod = widget.item!.paymentMethod;
      _paidAt = widget.item!.paidAt?.toDate();
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final db = FirestoreConfig.instance;
      
      final evSnap = await db.collection(Collections.events).get();
      _events = evSnap.docs.map((d) => {'id': d.id, 'name': d.data()['title'] ?? d.id}).toList();

      final bkSnap = await db.collection(Collections.bookings).get();
      _bookings = bkSnap.docs.map((d) => {'id': d.id, 'name': 'Booking ${d.id}'}).toList();

      if (widget.item != null) {
        if (_events.any((e) => e['id'] == widget.item!.eventId)) _selectedEvent = widget.item!.eventId;
        if (_bookings.any((e) => e['id'] == widget.item!.bookingId)) _selectedBooking = widget.item!.bookingId;
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
      title: Text(widget.item == null ? 'New Payment Record' : 'Edit Payment Record'),
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
                value: _selectedBooking,
                decoration: const InputDecoration(labelText: 'Booking'),
                items: _bookings.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))).toList(),
                onChanged: (v) => setState(() => _selectedBooking = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              TextFormField(
                controller: _customerCtrl,
                decoration: const InputDecoration(labelText: 'Customer ID (User ID)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _currencyCtrl,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['card', 'bank_transfer', 'cash', 'upi', 'wallet']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
              TextFormField(
                controller: _transactionCtrl,
                decoration: const InputDecoration(labelText: 'Transaction ID'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['pending', 'paid', 'failed', 'refunded', 'partially_paid']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _status = v!;
                    if (_status == 'paid' && _paidAt == null) {
                      _paidAt = DateTime.now();
                    }
                  });
                },
              ),
              if (_status == 'paid' || _status == 'partially_paid')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paid At'),
                  subtitle: Text(_paidAt != null ? DateFormat.yMd().add_Hm().format(_paidAt!) : 'Not set'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: _paidAt ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (date != null && mounted) {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_paidAt ?? DateTime.now()));
                      if (time != null) setState(() => _paidAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    }
                  },
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

    if (_status == 'paid' && _paidAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paid At is required when status is paid.')));
      return;
    }

    final item = PaymentModel(
      paymentId: widget.item?.paymentId ?? '',
      eventId: _selectedEvent!,
      bookingId: _selectedBooking!,
      customerId: _customerCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      currency: _currencyCtrl.text.trim(),
      paymentMethod: _paymentMethod,
      transactionId: _transactionCtrl.text.trim(),
      status: _status,
      paidAt: _paidAt != null ? Timestamp.fromDate(_paidAt!) : null,
      createdAt: widget.item?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.item == null) {
        await PaymentsRepository.create(item);
      } else {
        await PaymentsRepository.update(item);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

