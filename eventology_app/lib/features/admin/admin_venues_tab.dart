import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/venue_model.dart';
import '../../services/firestore/venue_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/database/collections.dart';
import '../../core/firebase/firestore_config.dart';

class AdminVenuesTab extends StatefulWidget {
  const AdminVenuesTab({super.key});

  @override
  State<AdminVenuesTab> createState() => _AdminVenuesTabState();
}

class _AdminVenuesTabState extends State<AdminVenuesTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _verifiedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<VenueModel>>(
            stream: VenueRepository.streamVenues(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: \${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var venues = snapshot.data!;

              // Apply Search
              if (_searchQuery.isNotEmpty) {
                venues = venues.where((v) =>
                  v.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              // Apply Status Filter
              if (_statusFilter != 'All') {
                venues = venues.where((v) => v.status == _statusFilter.toLowerCase()).toList();
              }

              // Apply Verified Filter
              if (_verifiedFilter != 'All') {
                final isVer = _verifiedFilter == 'Verified';
                venues = venues.where((v) => v.verified == isVer).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: venues.length,
                itemBuilder: (context, index) {
                  final venue = venues[index];
                  return _buildVenueCard(venue);
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
                hintText: 'Search venues...',
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
            label: const Text('New Venue', style: TextStyle(color: AppColors.background)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => _showVenueDialog(null),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueCard(VenueModel venue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text(venue.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Contact: ${venue.contactName ?? 'N/A'} (${venue.contactPhone ?? 'N/A'})"),
            Text('Capacity: \${venue.capacity} | Price: ₹\${venue.priceFrom ?? 0} - ₹\${venue.priceTo ?? 0}'),
            Text("Status: ${venue.status.toUpperCase()} | ${venue.verified ? 'VERIFIED' : 'UNVERIFIED'}"),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!venue.verified)
              IconButton(
                icon: const Icon(Icons.verified, color: Colors.green),
                tooltip: 'Verify Venue',
                onPressed: () => VenueRepository.updateVenue(venue.copyWith(verified: true)),
              ),
            if (venue.status != 'active')
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.blue),
                tooltip: 'Activate',
                onPressed: () => VenueRepository.updateVenue(venue.copyWith(status: 'active')),
              ),
            if (venue.status == 'active')
              IconButton(
                icon: const Icon(Icons.pause, color: Colors.orange),
                tooltip: 'Suspend',
                onPressed: () => VenueRepository.updateVenue(venue.copyWith(status: 'suspended')),
              ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _showVenueDialog(venue),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => VenueRepository.deleteVenue(venue.venueId),
            ),
          ],
        ),
      ),
    );
  }

  void _showVenueDialog(VenueModel? venue) {
    showDialog(
      context: context,
      builder: (context) => _VenueFormDialog(venue: venue),
    );
  }
}

class _VenueFormDialog extends StatefulWidget {
  final VenueModel? venue;
  const _VenueFormDialog({this.venue});

  @override
  State<_VenueFormDialog> createState() => _VenueFormDialogState();
}

class _VenueFormDialogState extends State<_VenueFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _priceFromCtrl = TextEditingController();
  final _priceToCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  
  String _status = 'pending';
  bool _verified = false;

  String? _selectedLocation;
  String? _selectedVenueType;
  
  List<String> _amenities = [];
  final _amenityCtrl = TextEditingController();

  List<Map<String, dynamic>> _allLocations = [];
  List<Map<String, dynamic>> _allVenueTypes = [];

  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    if (widget.venue != null) {
      _nameCtrl.text = widget.venue!.name;
      _descCtrl.text = widget.venue!.description ?? '';
      _capacityCtrl.text = widget.venue!.capacity.toString();
      _priceFromCtrl.text = widget.venue!.priceFrom?.toString() ?? '';
      _priceToCtrl.text = widget.venue!.priceTo?.toString() ?? '';
      _contactNameCtrl.text = widget.venue!.contactName ?? '';
      _contactPhoneCtrl.text = widget.venue!.contactPhone ?? '';
      _status = widget.venue!.status;
      _verified = widget.venue!.verified;
      _selectedLocation = widget.venue!.locationId;
      _selectedVenueType = widget.venue!.venueTypeId;
      _amenities = List.from(widget.venue!.amenities);
    }
    _fetchMasterData();
  }

  Future<void> _fetchMasterData() async {
    try {
      final db = FirestoreConfig.instance;
      
      final locSnap = await db.collection(Collections.locations).get();
      _allLocations = locSnap.docs.map((d) => {'id': d.id, 'name': d.data()['city'] ?? d.id}).toList();

      final vtSnap = await db.collection(Collections.venueTypes).get();
      _allVenueTypes = vtSnap.docs.map((d) => {'id': d.id, 'name': d.data()['name']}).toList();

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
      title: Text(widget.venue == null ? 'New Venue' : 'Edit Venue'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Venue Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              DropdownButtonFormField<String?>(
                value: _selectedVenueType,
                decoration: const InputDecoration(labelText: 'Venue Type'),
                items: _allVenueTypes.map((vt) => DropdownMenuItem<String>(value: vt['id'], child: Text(vt['name']))).toList(),
                onChanged: (v) => setState(() => _selectedVenueType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              DropdownButtonFormField<String?>(
                value: _selectedLocation,
                decoration: const InputDecoration(labelText: 'Location'),
                items: _allLocations.map((l) => DropdownMenuItem<String>(value: l['id'], child: Text(l['name']))).toList(),
                onChanged: (v) => setState(() => _selectedLocation = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              TextFormField(
                controller: _capacityCtrl,
                decoration: const InputDecoration(labelText: 'Capacity (Number)'),
                keyboardType: TextInputType.number,
                validator: (v) => int.tryParse(v!) == null ? 'Valid number required' : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceFromCtrl,
                      decoration: const InputDecoration(labelText: 'Price From'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _priceToCtrl,
                      decoration: const InputDecoration(labelText: 'Price To'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _contactNameCtrl,
                decoration: const InputDecoration(labelText: 'Contact Name'),
              ),
              TextFormField(
                controller: _contactPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Contact Phone'),
              ),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['pending', 'active', 'suspended', 'inactive']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              CheckboxListTile(
                title: const Text('Verified'),
                value: _verified,
                onChanged: (v) => setState(() => _verified = v!),
              ),
              
              const Divider(),
              const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amenityCtrl,
                      decoration: const InputDecoration(hintText: 'Add amenity'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_amenityCtrl.text.isNotEmpty) {
                        setState(() {
                          _amenities.add(_amenityCtrl.text.trim());
                          _amenityCtrl.clear();
                        });
                      }
                    },
                  )
                ],
              ),
              Wrap(
                spacing: 8,
                children: _amenities.map((a) => Chip(
                  label: Text(a),
                  onDeleted: () => setState(() => _amenities.remove(a)),
                )).toList(),
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
    
    final venue = VenueModel(
      venueId: widget.venue?.venueId ?? '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      venueTypeId: _selectedVenueType!,
      locationId: _selectedLocation!,
      capacity: int.parse(_capacityCtrl.text.trim()),
      priceFrom: double.tryParse(_priceFromCtrl.text.trim()),
      priceTo: double.tryParse(_priceToCtrl.text.trim()),
      amenities: _amenities,
      images: widget.venue?.images ?? [],
      contactName: _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
      status: _status,
      verified: _verified,
      createdAt: widget.venue?.createdAt ?? Timestamp.now(),
    );

    try {
      if (widget.venue == null) {
        await VenueRepository.createVenue(venue);
      } else {
        await VenueRepository.updateVenue(venue);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
      }
    }
  }
}
