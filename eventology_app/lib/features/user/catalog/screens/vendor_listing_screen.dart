import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/firestore/catalog_repository.dart';
import '../../../../models/vendor_model.dart';
import '../../../../core/theme/app_colors.dart';

class VendorListingScreen extends StatelessWidget {
  final String? categoryId;
  const VendorListingScreen({super.key, this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENDORS', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: categoryId == null
          ? _buildAllVendorsStream()
          : _buildCategoryVendorsStream(),
    );
  }

  Widget _buildAllVendorsStream() {
    return StreamBuilder<List<VendorModel>>(
      stream: CatalogRepository.streamFeaturedVendors(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final vendors = snapshot.data ?? [];
        return _buildVendorList(vendors);
      },
    );
  }

  Widget _buildCategoryVendorsStream() {
    return StreamBuilder<List<VendorModel>>(
      stream: CatalogRepository.streamVendorsByCategory(categoryId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final vendors = snapshot.data ?? [];
        return _buildVendorList(vendors);
      },
    );
  }

  Widget _buildVendorList(List<VendorModel> vendors) {
    if (vendors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('No vendors found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Try exploring a different category or ask the AI Architect.', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vendors.length,
      itemBuilder: (context, index) {
        final vendor = vendors[index];
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => context.push('/vendors/${vendor.vendorId}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLighter,
                      borderRadius: BorderRadius.circular(12),
                      image: vendor.portfolioImages != null && vendor.portfolioImages!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(vendor.portfolioImages!.first),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: vendor.portfolioImages == null || vendor.portfolioImages!.isEmpty
                        ? const Icon(Icons.storefront, color: AppColors.textSecondary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor.businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(vendor.rating?.toStringAsFixed(1) ?? 'New', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vendor.description ?? 'Premium event services',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
