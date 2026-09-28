import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/location_model.dart';
import '../../services/firestore/location_repository.dart';

class AdminLocationsTab extends StatefulWidget {
  const AdminLocationsTab({super.key});

  @override
  State<AdminLocationsTab> createState() => _AdminLocationsTabState();
}

class _AdminLocationsTabState extends State<AdminLocationsTab> {
  final _formKey = GlobalKey<FormState>();
  
  String _country = '';
  String _state = '';
  String _city = '';
  String _area = '';
  String _pincode = '';
  double _latitude = 0.0;
  double _longitude = 0.0;

  void _showAddLocationDialog(BuildContext context, {LocationModel? existing}) {
    if (existing != null) {
      _country = existing.country;
      _state = existing.state;
      _city = existing.city;
      _area = existing.area;
      _pincode = existing.pincode;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
    } else {
      _country = '';
      _state = '';
      _city = '';
      _area = '';
      _pincode = '';
      _latitude = 0.0;
      _longitude = 0.0;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existing == null ? 'Add Location' : 'Edit Location', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: _country,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Country *', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    onSaved: (val) => _country = val!.trim(),
                  ),
                  TextFormField(
                    initialValue: _state,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'State *', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    onSaved: (val) => _state = val!.trim(),
                  ),
                  TextFormField(
                    initialValue: _city,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'City *', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                    onSaved: (val) => _city = val!.trim(),
                  ),
                  TextFormField(
                    initialValue: _area,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Area', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    onSaved: (val) => _area = val?.trim() ?? '',
                  ),
                  TextFormField(
                    initialValue: _pincode,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Pincode', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final regex = RegExp(r'^[a-zA-Z0-9\s-]{3,10}$');
                        if (!regex.hasMatch(val.trim())) {
                          return 'Invalid pincode format';
                        }
                      }
                      return null;
                    },
                    onSaved: (val) => _pincode = val?.trim() ?? '',
                  ),
                  TextFormField(
                    initialValue: _latitude.toString(),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Latitude', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final v = double.tryParse(val.trim());
                        if (v == null || v < -90 || v > 90) return 'Must be between -90 and 90';
                      }
                      return null;
                    },
                    onSaved: (val) => _latitude = double.tryParse(val?.trim() ?? '') ?? 0.0,
                  ),
                  TextFormField(
                    initialValue: _longitude.toString(),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Longitude', labelStyle: TextStyle(color: AppColors.textSecondary)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final v = double.tryParse(val.trim());
                        if (v == null || v < -180 || v > 180) return 'Must be between -180 and 180';
                      }
                      return null;
                    },
                    onSaved: (val) => _longitude = double.tryParse(val?.trim() ?? '') ?? 0.0,
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
                    final newLoc = LocationModel(
                      locationId: existing?.locationId ?? '',
                      country: _country,
                      state: _state,
                      city: _city,
                      area: _area,
                      pincode: _pincode,
                      latitude: _latitude,
                      longitude: _longitude,
                    );
                    
                    if (existing == null) {
                      await LocationRepository.createLocation(newLoc);
                    } else {
                      await LocationRepository.updateLocation(newLoc);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, color: AppColors.background),
                label: const Text('Add Location', style: TextStyle(color: AppColors.background)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => _showAddLocationDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LocationModel>>(
            stream: LocationRepository.streamLocations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              
              final locations = snapshot.data ?? [];
              if (locations.isEmpty) {
                return const Center(child: Text('No locations found.', style: TextStyle(color: AppColors.textSecondary)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final loc = locations[index];
                  return Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('\${loc.city}, \${loc.state}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('\${loc.country} - \${loc.pincode}\\nLat: \${loc.latitude}, Lng: \${loc.longitude}', style: const TextStyle(color: AppColors.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _showAddLocationDialog(context, existing: loc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: const Text('Delete Location?', style: TextStyle(color: Colors.white)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await LocationRepository.deleteLocation(loc.locationId);
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
