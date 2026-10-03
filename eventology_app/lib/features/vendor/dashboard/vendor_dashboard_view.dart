import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../vendor_session.dart';
import '../../../services/firestore/enquiries_repository.dart';
import '../../../services/firestore/bookings_repository.dart';
import 'package:intl/intl.dart';
class VendorDashboardView extends StatelessWidget {
  const VendorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final vendor = VendorSession.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.95),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Vendor Lead Hub',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white10),
                          image: vendor.mediaGallery.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(vendor.mediaGallery.first),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: AppColors.surfaceHighlight,
                        ),
                        child: vendor.mediaGallery.isEmpty
                            ? const Icon(Icons.business, color: Colors.white54)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                vendor.businessName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AppColors.primary, size: 14),
                            ],
                          ),
                          const Text(
                            'Premium Vendor',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.primary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          (vendor.rating ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Metrics Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder(
                stream: EnquiriesRepository.streamVendorEnquiries(vendor.id),
                builder: (context, enquirySnapshot) {
                  return StreamBuilder(
                    stream: BookingsRepository.streamVendorBookings(vendor.id),
                    builder: (context, bookingSnapshot) {
                      final enquiries = enquirySnapshot.data ?? [];
                      final bookings = bookingSnapshot.data ?? [];
                      
                      final pendingEnquiries = enquiries.where((e) => e.status == 'pending').length;
                      final activeInterest = enquiries.where((e) => e.status == 'vendor_accepted').length;
                      
                      double earnings = 0;
                      for (var b in bookings) {
                        if (b.status == 'confirmed' || b.status == 'completed') {
                          earnings += b.totalAmount;
                        }
                      }
                      
                      return Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard('Inquiries', pendingEnquiries.toString(), '+new', Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard('Interest', activeInterest.toString(), 'active', AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard('Earnings', '₹${(earnings/100000).toStringAsFixed(1)}L', 'All time', AppColors.textSecondary),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Leads Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Leads for You',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.tune, color: AppColors.primary, size: 16),
                    label: const Text(
                      'Filter',
                      style: TextStyle(color: AppColors.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            // Leads List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder(
                stream: EnquiriesRepository.streamVendorEnquiries(vendor.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final enquiries = snapshot.data ?? [];
                  if (enquiries.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          "No active leads at the moment.",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    children: enquiries.map((e) => _buildLeadCard(context, e)).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, Color subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCard(BuildContext context, dynamic enquiry) {
    // Basic representation of a lead/enquiry card.
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              color: AppColors.surfaceHighlight,
              image: const DecorationImage(
                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuCt9KCDCjVqvBLq-9d5QEAqR4KyGssaJzSyB0NEKUN1u6iupUvP4kPKMyhfhOsj-vFxYglXQ2U-034R6mOoQ3EZSuDjHN7bjekc0noS4OB4y8O8LtK7qeCpJrjapQinP86DbMTNbRMhmtonGgBMAMfhDJYAMEf9yvJT23JPLdeUd2SmOZy5Gu4Oo6EqTX9rH9ls_iHAogHL6RZwyROdlwdwaFaqlLveA0fJd6JcbTjSZUs1ZRon_-s35qYj8J55W2FLZ5HwW3UqzQ'),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.surface.withOpacity(1.0),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      if (enquiry.status == 'pending')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Text(
                            'NEW LEAD',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Text(
                    'Enquiry #${enquiry.id.substring(0, 5)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(enquiry.targetDate.toDate()),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      'Status: ${enquiry.status}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  enquiry.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (enquiry.status == 'pending')
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Respond to Lead', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
