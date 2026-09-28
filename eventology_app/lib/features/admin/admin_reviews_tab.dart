import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/reviews_model.dart';
import '../../services/firestore/reviews_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import 'package:intl/intl.dart';

class AdminReviewsTab extends StatefulWidget {
  const AdminReviewsTab({super.key});

  @override
  State<AdminReviewsTab> createState() => _AdminReviewsTabState();
}

class _AdminReviewsTabState extends State<AdminReviewsTab> {
  String _searchQuery = '';
  String _ratingFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<ReviewModel>>(
            stream: ReviewsRepository.stream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var items = snapshot.data!;

              if (_searchQuery.isNotEmpty) {
                items = items.where((i) =>
                  i.reviewId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  i.vendorId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (i.venueId?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();
              }

              if (_ratingFilter != 'All') {
                final rate = int.tryParse(_ratingFilter);
                if (rate != null) {
                  items = items.where((i) => i.rating == rate).toList();
                }
              }

              if (items.isEmpty) return const Center(child: Text('No reviews found.'));

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
                hintText: 'Search by Review ID, Vendor, or Venue...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _ratingFilter,
            items: ['All', '1', '2', '3', '4', '5']
                .map((e) => DropdownMenuItem(value: e, child: Text(e == 'All' ? 'All Ratings' : '$e Stars')))
                .toList(),
            onChanged: (val) => setState(() => _ratingFilter = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ReviewModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surfaceLighter,
      child: ListTile(
        title: Text('Review ID: ${item.reviewId} | Rating: ${item.rating}/5', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event: ${item.eventId} | Customer: ${item.customerId}'),
            Text('Vendor: ${item.vendorId} | Venue: ${item.venueId ?? "None"}'),
            Text('Date: ${DateFormat.yMd().add_Hm().format(item.createdAt.toDate())}'),
            const SizedBox(height: 4),
            Text('"${item.comment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => _confirmDelete(item.reviewId),
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ReviewsRepository.delete(id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

