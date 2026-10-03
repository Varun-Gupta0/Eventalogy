import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/firestore/catalog_repository.dart';
import '../../../../models/venue_model.dart';
import '../../../../core/theme/app_colors.dart';

class VenueListingScreen extends StatelessWidget {
  const VenueListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENUES', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<VenueModel>>(
        stream: CatalogRepository.streamActiveVenues(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final venues = snapshot.data ?? [];
          if (venues.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text('No venues available', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Check back later or ask the AI Architect.', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: venues.length,
            itemBuilder: (context, index) {
              final venue = venues[index];
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/venues/${venue.venueId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLighter,
                          image: venue.images.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(venue.images.first),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: venue.images.isEmpty
                            ? const Center(child: Icon(Icons.image, size: 48, color: AppColors.textSecondary))
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    venue.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (venue.priceFrom != null)
                                  Text(
                                    '₹${venue.priceFrom!.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.group, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('Up to ${venue.capacity} guests', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const SizedBox(width: 16),
                                if (venue.verified) ...[
                                  const Icon(Icons.verified, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  const Text('Verified', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
