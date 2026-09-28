import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vendor_model.dart';
import '../../services/firestore/vendor_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/database/collections.dart';
import '../../core/firebase/firestore_config.dart';

class AdminVendorsTab extends StatefulWidget {
  const AdminVendorsTab({super.key});

  @override
  State<AdminVendorsTab> createState() => _AdminVendorsTabState();
}

class _AdminVendorsTabState extends State<AdminVendorsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _verifiedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<VendorModel>>(
            stream: VendorRepository.streamVendors(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: \${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var vendors = snapshot.data!;

              // Apply Search
              if (_searchQuery.isNotEmpty) {
                vendors = vendors.where((v) =>
                  v.businessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  v.ownerName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              // Apply Status Filter
              if (_statusFilter != 'All') {
                vendors = vendors.where((v) => v.status == _statusFilter.toLowerCase()).toList();
              }

              // Apply Verified Filter
              if (_verifiedFilter != 'All') {
                final isVer = _verifiedFilter == 'Verified';
                vendors = vendors.where((v) => v.verified == isVer).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vendors.length,
                itemBuilder: (context, index) {
                  final vendor = vendors[index];
                  return _buildVendorCard(vendor);
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
                hintText: 'Search business or owner...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'Pending', 'Active', 'Suspended', 'Inactive']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _verifiedFilter,
            items: ['All', 'Verified', 'Unverified']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _verifiedFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Vendor', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showVendorDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(VendorModel vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text(vendor.businessName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner: \${vendor.ownerName} | UserId: \${vendor.userId}'),
            Text('Categories: \${vendor.categoryIds.length} | Services: \${vendor.serviceIds?.length ?? 0}'),
            Text("Status: ${vendor.status.toUpperCase()} | ${vendor.verified ? 'VERIFIED' : 'UNVERIFIED'}"),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!vendor.verified)
              IconButton(
                icon: const Icon(Icons.verified, color: Colors.green),
                tooltip: 'Verify Vendor',
                onPressed: () => VendorRepository.updateVendor(vendor.copyWith(verified: true)),
              ),
            if (vendor.status != 'active')
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.blue),
                tooltip: 'Activate',
                onPressed: () => VendorRepository.updateVendor(vendor.copyWith(status: 'active')),
              ),
            if (vendor.status == 'active')
              IconButton(
                icon: const Icon(Icons.pause, color: Colors.orange),
                tooltip: 'Suspend',
                onPressed: () => VendorRepository.updateVendor(vendor.copyWith(status: 'suspended')),
              ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _showVendorDialog(vendor),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => VendorRepository.deleteVendor(vendor.vendorId),
            ),
          ],
        ),
      ),
    );
  }

  void _showVendorDialog(VendorModel? vendor) {
    showDialog(
      context: context,
      builder: (context) => _VendorFormDialog(vendor: vendor),
    );
  }
}

class _VendorFormDialog extends StatefulWidget {
  final VendorModel? vendor;
  const _VendorFormDialog({this.vendor});

  @override
  State<_VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<_VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  String _status = 'pending';
  String? _pricingModel;
  bool _verified = false;

  List<String> _selectedCategories = [];
  List<String> _selectedServices = [];
  String? _selectedLocation;

  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _allLocations = [];

  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.vendor != null) {
      _businessNameCtrl.text = widget.vendor!.businessName;
      _ownerNameCtrl.text = widget.vendor!.ownerName;
      _userIdCtrl.text = widget.vendor!.userId;
      _emailCtrl.text = widget.vendor!.email ?? '';
      _phoneCtrl.text = widget.vendor!.phone ?? '';
      _status = widget.vendor!.status;
      _pricingModel = widget.vendor!.pricingModel;
      _verified = widget.vendor!.verified;
      _selectedCategories = List.from(widget.vendor!.categoryIds);
      _selectedServices = widget.vendor!.serviceIds != null ? List.from(widget.vendor!.serviceIds!) : [];
      _selectedLocation = widget.vendor!.locationId;
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final db = FirestoreConfig.instance;
      
      final catSnap = await db.collection(Collections.categories).get();
      _allCategories = catSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

      final srvSnap = await db.collection(Collections.services).get();
      _allServices = srvSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

      final locSnap = await db.collection(Collections.locations).get();
      _allLocations = locSnap.docs.map((d) => {'id': d.id, 'name': d.data()['city'] ?? d.id}).toList();

    } catch (e) {
      debugPrint("Error fetching master data: \$e");
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
      title: Text(widget.vendor == null ? 'New Vendor' : 'Edit Vendor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _userIdCtrl,
                decoration: const InputDecoration(labelText: 'User ID (Owner)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _businessNameCtrl,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(labelText: 'Owner Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email (Optional)'),
              ),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone (Optional)'),
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['pending', 'active', 'suspended', 'inactive']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              DropdownButtonFormField<String?>(
                value: _pricingModel,
                decoration: const InputDecoration(labelText: 'Pricing Model'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...['fixed', 'per_person', 'hourly', 'custom', 'package']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                ],
                onChanged: (v) => setState(() => _pricingModel = v),
              ),
              CheckboxListTile(
                title: const Text('Verified'),
                value: _verified,
                onChanged: (v) => setState(() => _verified = v!),
              ),
              
              const Divider(),
              const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String?>(
                value: _selectedLocation,
                hint: const Text('Select Location'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._allLocations.map((l) => DropdownMenuItem<String>(value: l['id'], child: Text(l['name'])))
                ],
                onChanged: (v) => setState(() => _selectedLocation = v),
              ),

              const Divider(),
              const Text('Categories (Select multiple)', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _allCategories.map((cat) {
                  final isSelected = _selectedCategories.contains(cat['id']);
                  return FilterChip(
                    label: Text(cat['name']),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(cat['id']);
                        } else {
                          _selectedCategories.remove(cat['id']);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const Divider(),
              const Text('Services (Select multiple)', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _allServices.map((srv) {
                  final isSelected = _selectedServices.contains(srv['id']);
                  return FilterChip(
                    label: Text(srv['name']),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedServices.add(srv['id']);
                        } else {
                          _selectedServices.remove(srv['id']);
                        }
                      });
                    },
                  );
                }).toList(),
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
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one category is required')));
      return;
    }

    final vendor = VendorModel(
      vendorId: widget.vendor?.vendorId ?? '',
      userId: _userIdCtrl.text.trim(),
      businessName: _businessNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      status: _status,
      pricingModel: _pricingModel,
      verified: _verified,
      categoryIds: _selectedCategories,
      serviceIds: _selectedServices.isNotEmpty ? _selectedServices : null,
      locationId: _selectedLocation,
      createdAt: widget.vendor?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.vendor == null) {
        await VendorRepository.createVendor(vendor);
      } else {
        await VendorRepository.updateVendor(vendor);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
      }
    }
  }
}
