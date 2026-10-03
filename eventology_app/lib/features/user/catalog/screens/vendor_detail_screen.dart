import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/firestore/catalog_repository.dart';
import '../../../../models/vendor_model.dart';
import '../../../../core/theme/app_colors.dart';

class VendorDetailScreen extends StatelessWidget {
  final String vendorId;
  const VendorDetailScreen({super.key, required this.vendorId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VendorModel?>(
      future: CatalogRepository.getVendor(vendorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        
        final vendor = snapshot.data;
        if (vendor == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  SizedBox(height: 16),
                  Text('Vendor Not Found', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroImage(vendor),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              vendor.businessName,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          if (vendor.verified)
                            const Icon(Icons.verified, color: AppColors.primary, size: 24),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text('${vendor.rating?.toStringAsFixed(1) ?? 'New'} Rating', style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 12),
                      Text(
                        vendor.description ?? 'No description provided.',
                        style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      if (vendor.portfolioImages != null && vendor.portfolioImages!.isNotEmpty) ...[
                        const Text('Portfolio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: vendor.portfolioImages!.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: NetworkImage(vendor.portfolioImages![index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: ElevatedButton(
              onPressed: () {
                context.push('/ai-planner');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Plan with AI Architect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroImage(VendorModel vendor) {
    if (vendor.portfolioImages == null || vendor.portfolioImages!.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: AppColors.surfaceLighter,
        child: const Icon(Icons.storefront, size: 64, color: AppColors.textSecondary),
      );
    }
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(vendor.portfolioImages!.first),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.5),
              Colors.transparent,
              AppColors.background,
            ],
          ),
        ),
      ),
    );
  }
}
