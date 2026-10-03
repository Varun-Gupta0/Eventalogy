import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/firestore/catalog_repository.dart';
import '../../../models/event_type_model.dart';
import '../../../core/theme/app_colors.dart';

class UserPlannerView extends StatelessWidget {
  const UserPlannerView({super.key});

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'EVENT PLANNER',
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
            top: -50,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPurple.withOpacity(0.05),
              ),
            ),
          ),
          StreamBuilder<List<EventTypeModel>>(
            stream: CatalogRepository.streamActiveEventTypes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final eventTypes = snapshot.data ?? [];
              if (eventTypes.isEmpty) {
                return const Center(
                  child: Text('No event types available', style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
                itemCount: eventTypes.length,
                itemBuilder: (context, index) {
                  final event = eventTypes[index];
                  return GestureDetector(
                    onTap: () {
                      context.push('/planner/details/${event.eventTypeId}');
                    },
                    child: Container(
                      height: 200,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.surfaceLighter, AppColors.background],
                        ),
                        border: Border.all(color: AppColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Text(
                                'ELITE TIER',
                                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.name,
                                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [const Shadow(color: Colors.black, blurRadius: 10)],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Customizable templates',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('Explore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
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
        ],
      ),
    );
  }
}
