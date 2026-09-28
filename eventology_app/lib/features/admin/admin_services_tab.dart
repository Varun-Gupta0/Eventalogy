import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/service_model.dart';
import '../../services/firestore/service_repository.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';

class AdminServicesTab extends StatefulWidget {
  const AdminServicesTab({super.key});

  @override
  State<AdminServicesTab> createState() => _AdminServicesTabState();
}

class _AdminServicesTabState extends State<AdminServicesTab> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String? _categoryId;
  String _pricingModel = 'fixed';
  double? _basePrice;
  String? _description;

  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final snap = await FirestoreConfig.instance.collection(Collections.categories).get();
    setState(() {
      _categories = snap.docs.map((doc) => {'id': doc.id, 'name': doc.data()['name']}).toList();
    });
  }

  void _showAddServiceDialog(BuildContext context, {ServiceModel? existing}) {
    if (existing != null) {
      _name = existing.name;
      _categoryId = existing.categoryId;
      _pricingModel = existing.pricingModel;
      _basePrice = existing.basePrice;
      _description = existing.description;
    } else {
      _name = '';
      _categoryId = _categories.isNotEmpty ? _categories.first['id'] as String : null;
      _pricingModel = 'fixed';
      _basePrice = null;
      _description = null;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(existing == null ? 'Add Service' : 'Edit Service', style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: _name,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Name *', labelStyle: TextStyle(color: AppColors.textSecondary)),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                        onSaved: (val) => _name = val!.trim(),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Category *', labelStyle: TextStyle(color: AppColors.textSecondary)),
                        items: _categories.map((c) => DropdownMenuItem<String>(
                          value: c['id'] as String,
                          child: Text(c['name'] as String),
                        )).toList(),
                        onChanged: (val) {
                          setDialogState(() => _categoryId = val);
                        },
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _pricingModel,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Pricing Model *', labelStyle: TextStyle(color: AppColors.textSecondary)),
                        items: const [
                          DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom')),
                          DropdownMenuItem(value: 'per_person', child: Text('Per Person')),
                          DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                        ],
                        onChanged: (val) {
                          setDialogState(() => _pricingModel = val!);
                        },
                      ),
                      TextFormField(
                        initialValue: _basePrice?.toString() ?? '',
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Base Price', labelStyle: TextStyle(color: AppColors.textSecondary)),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onSaved: (val) => _basePrice = double.tryParse(val?.trim() ?? ''),
                      ),
                      TextFormField(
                        initialValue: _description ?? '',
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Description', labelStyle: TextStyle(color: AppColors.textSecondary)),
                        maxLines: 2,
                        onSaved: (val) => _description = (val == null || val.trim().isEmpty) ? null : val.trim(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      try {
                        final newSvc = ServiceModel(
                          serviceId: existing?.serviceId ?? '',
                          name: _name,
                          categoryId: _categoryId!,
                          pricingModel: _pricingModel,
                          basePrice: _basePrice,
                          description: _description,
                          active: existing?.active ?? true,
                          createdAt: existing?.createdAt ?? Timestamp.now(),
                        );
                        
                        if (existing == null) {
                          await ServiceRepository.createService(newSvc);
                        } else {
                          await ServiceRepository.updateService(newSvc);
                        }
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
                        }
                      }
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: AppColors.background)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, color: AppColors.background),
                    label: const Text('Seed Initial Services', style: TextStyle(color: AppColors.background)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                    onPressed: () async {
                      try {
                        final result = await ServiceRepository.seedInitialServices();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              "Seed complete: ${result['created']} created, ${result['skipped']} skipped. "
                              "${(result['errors'] as List).isNotEmpty ? 'Errors: ${result['errors']}' : ''}"
                            ),
                            duration: const Duration(seconds: 4),
                          ));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: AppColors.background),
                    label: const Text('Add Service', style: TextStyle(color: AppColors.background)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => _showAddServiceDialog(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ServiceModel>>(
            stream: ServiceRepository.streamServices(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              
              final services = snapshot.data ?? [];
              if (services.isEmpty) {
                return const Center(child: Text('No services found.', style: TextStyle(color: AppColors.textSecondary)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final svc = services[index];
                  // Retrieve category name
                  final catName = _categories.firstWhere((c) => c['id'] == svc.categoryId, orElse: () => {'name': 'Unknown'})['name'];
                  
                  return Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(svc.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Category: \$catName\\nPricing: \${svc.pricingModel}\${svc.basePrice != null ? " (\$\${svc.basePrice})" : ""}', style: const TextStyle(color: AppColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _showAddServiceDialog(context, existing: svc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Delete Service?', style: TextStyle(color: Colors.white)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ServiceRepository.deleteService(svc.serviceId);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
