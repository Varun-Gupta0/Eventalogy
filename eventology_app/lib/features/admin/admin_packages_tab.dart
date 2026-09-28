import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/package_model.dart';
import '../../services/firestore/package_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/database/collections.dart';
import '../../core/firebase/firestore_config.dart';

class AdminPackagesTab extends StatefulWidget {
  const AdminPackagesTab({super.key});

  @override
  State<AdminPackagesTab> createState() => _AdminPackagesTabState();
}

class _AdminPackagesTabState extends State<AdminPackagesTab> {
  String _searchQuery = '';
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<PackageModel>>(
            stream: PackageRepository.streamPackages(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: \${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var packages = snapshot.data!;

              // Apply Search
              if (_searchQuery.isNotEmpty) {
                packages = packages.where((p) =>
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              // Apply Active Filter
              if (_activeFilter != 'All') {
                final isActive = _activeFilter == 'Active';
                packages = packages.where((p) => p.active == isActive).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: packages.length,
                itemBuilder: (context, index) {
                  final pkg = packages[index];
                  return _buildPackageCard(pkg);
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
                hintText: 'Search packages...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _activeFilter,
            items: ['All', 'Active', 'Inactive']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _activeFilter = val!),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: AppColors.background),
            label: const Text('New Package', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showPackageDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(PackageModel pkg) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Services: \${pkg.serviceIds.length}'),
            Text("Price: ₹${pkg.price} | Discount: ${pkg.discount != null ? '₹${pkg.discount}' : 'None'}"),
            Text("Status: ${pkg.active ? 'ACTIVE' : 'INACTIVE'}"),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!pkg.active)
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                tooltip: 'Activate',
                onPressed: () => PackageRepository.updatePackage(pkg.copyWith(active: true)),
              ),
            if (pkg.active)
              IconButton(
                icon: const Icon(Icons.pause, color: Colors.orange),
                tooltip: 'Deactivate',
                onPressed: () => PackageRepository.updatePackage(pkg.copyWith(active: false)),
              ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _showPackageDialog(pkg),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => PackageRepository.deletePackage(pkg.packageId),
            ),
          ],
        ),
      ),
    );
  }

  void _showPackageDialog(PackageModel? pkg) {
    showDialog(
      context: context,
      builder: (context) => _PackageFormDialog(pkg: pkg),
    );
  }
}

class _PackageFormDialog extends StatefulWidget {
  final PackageModel? pkg;
  const _PackageFormDialog({this.pkg});

  @override
  State<_PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends State<_PackageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  
  bool _active = true;
  List<String> _selectedServices = [];

  List<Map<String, dynamic>> _allServices = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.pkg != null) {
      _nameCtrl.text = widget.pkg!.name;
      _descCtrl.text = widget.pkg!.description ?? '';
      _priceCtrl.text = widget.pkg!.price.toString();
      _discountCtrl.text = widget.pkg!.discount?.toString() ?? '';
      _active = widget.pkg!.active;
      _selectedServices = List.from(widget.pkg!.serviceIds);
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final db = FirestoreConfig.instance;
      
      final srvSnap = await db.collection(Collections.services).get();
      _allServices = srvSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

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
      title: Text(widget.pkg == null ? 'New Package' : 'Edit Package'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Package Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v!) == null ? 'Valid number required' : null,
              ),
              TextFormField(
                controller: _discountCtrl,
                decoration: const InputDecoration(labelText: 'Discount (Optional)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
                    return 'Valid number required';
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v!),
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
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one service is required')));
      return;
    }

    final pkg = PackageModel(
      packageId: widget.pkg?.packageId ?? '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      serviceIds: _selectedServices,
      price: double.parse(_priceCtrl.text.trim()),
      discount: _discountCtrl.text.trim().isEmpty ? null : double.parse(_discountCtrl.text.trim()),
      active: _active,
      createdAt: widget.pkg?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.pkg == null) {
        await PackageRepository.createPackage(pkg);
      } else {
        await PackageRepository.updatePackage(pkg);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
      }
    }
  }
}
