import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_recommendations_model.dart';
import '../../services/firestore/ai_recommendations_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminAiRecommendationsTab extends StatefulWidget {
  const AdminAiRecommendationsTab({super.key});

  @override
  State<AdminAiRecommendationsTab> createState() => _AdminAiRecommendationsTabState();
}

class _AdminAiRecommendationsTabState extends State<AdminAiRecommendationsTab> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<AiRecommendationModel>>(
            stream: AiRecommendationsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;
              items.sort((a, b) => b.score.compareTo(a.score)); // Sort by score descending

              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                items = items.where((i) =>
                  i.recommendationId.toLowerCase().contains(q) ||
                  i.eventId.toLowerCase().contains(q) ||
                  (i.serviceId?.toLowerCase().contains(q) ?? false) ||
                  (i.vendorId?.toLowerCase().contains(q) ?? false) ||
                  (i.venueId?.toLowerCase().contains(q) ?? false)).toList();
              }

              if (_statusFilter != 'All') {
                items = items.where((i) => i.status == _statusFilter).toList();
              }

              if (items.isEmpty) return const Center(child: Text('No recommendations found.'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildCard(items[index]);
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
                hintText: 'Search by ID, Event, Service, Vendor, Venue...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: ['All', 'active', 'accepted', 'rejected', 'expired']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Statuses' : e.toUpperCase())))
                .toList(),
            onChanged: (val) => setState(() => _statusFilter = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AiRecommendationModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ExpansionTile(
        title: Text('Rec: ${item.recommendationId} | Score: ${(item.score * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Event: ${item.eventId} | Status: ${item.status.toUpperCase()}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item.serviceId != null) Text('Service ID: ${item.serviceId}'),
                if (item.vendorId != null) Text('Vendor ID: ${item.vendorId}'),
                if (item.venueId != null) Text('Venue ID: ${item.venueId}'),
                const SizedBox(height: 8),
                const Text('Reasoning:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(item.reason),
                const SizedBox(height: 16),
                Text('Generated: ${DateFormat.yMd().add_Hm().format(item.createdAt.toDate())}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => _confirmDelete(item.recommendationId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recommendation'),
        content: const Text('Are you sure you want to delete this AI recommendation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AiRecommendationsRepository.delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

