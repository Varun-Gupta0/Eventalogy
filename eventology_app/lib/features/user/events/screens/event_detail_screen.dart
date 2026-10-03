import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/firestore/events_repository.dart';
import '../../../../services/firestore/bookings_repository.dart';
import '../../../../services/firestore/allocations_repository.dart';
import '../../../../models/events_model.dart';
import '../../../../models/bookings_model.dart';
import '../../../../models/allocations_model.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'EVENT DETAILS',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            letterSpacing: 2.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<EventModel?>(
        future: EventsRepository.getEvent(eventId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          final event = snapshot.data;
          
          if (event == null) {
            return const Center(child: Text('Event not found', style: TextStyle(color: Colors.white)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  event.title.isNotEmpty ? event.title : 'Unnamed Event',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        event.status.toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Details Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.calendar_today, 'Date', _formatDate(event.eventDate.toDate())),
                      const Divider(color: AppColors.glassBorder, height: 32),
                      _buildDetailRow(Icons.people, 'Guests', event.guestCount?.toString() ?? 'TBD'),
                      const Divider(color: AppColors.glassBorder, height: 32),
                      _buildDetailRow(Icons.attach_money, 'Budget', event.budget != null ? '₹${event.budget}' : 'TBD'),
                      const Divider(color: AppColors.glassBorder, height: 32),
                      _buildDetailRow(Icons.check_circle_outline, 'Payment Status', event.paymentStatus ?? 'Pending'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'BOOKINGS',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<BookingModel>>(
                  stream: BookingsRepository.streamEventBookings(event.eventId),
                  builder: (context, bookingSnapshot) {
                    if (bookingSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    final bookings = bookingSnapshot.data ?? [];
                    if (bookings.isEmpty) {
                      return const Text('No bookings found for this event.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14));
                    }
                    return Column(
                      children: bookings.map((b) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Booking #${b.id.substring(0, 8)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Amount: ₹${b.totalAmount}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: b.status == 'confirmed' ? Colors.green.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                b.status.toUpperCase(),
                                style: TextStyle(
                                  color: b.status == 'confirmed' ? Colors.green : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    );
                  }
                ),
                const SizedBox(height: 32),
                const Text(
                  'ALLOCATIONS',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<AllocationModel>>(
                  stream: AllocationsRepository.streamEventAllocations(event.eventId),
                  builder: (context, allocSnapshot) {
                    if (allocSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    final allocations = allocSnapshot.data ?? [];
                    if (allocations.isEmpty) {
                      return const Text('No allocations found for this event.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14));
                    }
                    return Column(
                      children: allocations.map((a) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Allocation #${a.id.substring(0, 8)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(a.vendorId ?? a.venueId ?? 'Resource', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                            Text(
                              a.status.toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )).toList(),
                    );
                  }
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
