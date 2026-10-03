import 'package:flutter/material.dart';
import '../../../services/firestore/catalog_repository.dart';
import '../../../services/firestore/package_repository.dart';
import '../../../models/event_type_model.dart';
import '../../../models/package_model.dart';
import '../../../core/theme/app_colors.dart';

class EventPlannerScreen extends StatelessWidget {
  final String eventTypeId;
  
  const EventPlannerScreen({super.key, required this.eventTypeId});

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'PACKAGES',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primary,
            letterSpacing: 2.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background.withOpacity(0.9),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 200,
            left: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentBlue.withOpacity(0.04),
              ),
            ),
          ),
          FutureBuilder<EventTypeModel?>(
            future: CatalogRepository.getEventType(eventTypeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final eventType = snapshot.data;
              if (eventType == null) {
                return const Center(child: Text('Event type not found', style: TextStyle(color: Colors.white)));
              }
              return StreamBuilder<List<PackageModel>>(
                stream: PackageRepository.streamActivePackages(),
                builder: (context, packageSnapshot) {
                  if (packageSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final packages = packageSnapshot.data ?? [];
                  if (packages.isEmpty) {
                    return const Center(child: Text('No packages available yet', style: TextStyle(color: AppColors.textSecondary)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final package = packages[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              package.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Featured', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        package.description ?? 'No description provided.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Request Quote',
                            style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${package.name} enquiry started', style: const TextStyle(color: Colors.black)),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLighter,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  ),
],
      ),
    );
  }
}
