import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/database/collections.dart';
import '../../core/firebase/firestore_config.dart';
import '../../models/vendor_model.dart';

class VendorRepository {
  static FirebaseFirestore get _db => FirestoreConfig.instance;
  static CollectionReference get _col => _db.collection(Collections.vendors);

  static const List<String> _validStatuses = ['pending', 'active', 'suspended', 'inactive'];
  static const List<String> _validPricingModels = ['fixed', 'per_person', 'hourly', 'custom', 'package'];

  static void _validate(VendorModel vendor) {
    if (vendor.userId.isEmpty) throw ArgumentError('userId is required');
    if (vendor.businessName.isEmpty) throw ArgumentError('businessName is required');
    if (vendor.ownerName.isEmpty) throw ArgumentError('ownerName is required');
    if (vendor.categoryIds.isEmpty) throw ArgumentError('At least one categoryId is required');
    
    if (!_validStatuses.contains(vendor.status)) {
      throw ArgumentError('Invalid status: ${vendor.status}');
    }
    
    if (vendor.pricingModel != null && vendor.pricingModel!.isNotEmpty) {
      if (!_validPricingModels.contains(vendor.pricingModel)) {
        throw ArgumentError('Invalid pricingModel: ${vendor.pricingModel}');
      }
    }
    
    if (vendor.rating != null && (vendor.rating! < 0 || vendor.rating! > 5)) {
      throw ArgumentError('Rating must be between 0 and 5');
    }
  }

  static Future<String> createVendor(VendorModel vendor) async {
    _validate(vendor);
    
    // Ensure document ID matches vendorId if provided, else generate
    final ref = vendor.vendorId.isNotEmpty ? _col.doc(vendor.vendorId) : _col.doc();
    
    final newVendor = vendor.copyWith(
      vendorId: ref.id,
      createdAt: vendor.createdAt, // usually Timestamp.now() passed in
    );

    await ref.set(newVendor.toFirestore());
    return ref.id;
  }

  static Future<VendorModel?> getVendor(String vendorId) async {
    final doc = await _col.doc(vendorId).get();
    if (!doc.exists) return null;
    return VendorModel.fromFirestore(doc);
  }

  static Future<VendorModel?> getVendorByUserId(String userId) async {
    final snapshot = await _col.where('userId', isEqualTo: userId).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return VendorModel.fromFirestore(snapshot.docs.first);
  }

  static Future<void> updateVendor(VendorModel vendor) async {
    _validate(vendor);
    final ref = _col.doc(vendor.vendorId);
    
    final updatedVendor = vendor.copyWith(
      updatedAt: Timestamp.now(),
    );
    
    await ref.update(updatedVendor.toFirestore());
  }

  static Future<void> deleteVendor(String vendorId) async {
    await _col.doc(vendorId).delete();
  }

  static Stream<List<VendorModel>> streamVendors() {
    return _col.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => VendorModel.fromFirestore(doc)).toList());
  }

  static Stream<VendorModel?> streamVendorById(String vendorId) {
    return _col.doc(vendorId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return VendorModel.fromFirestore(doc);
    });
  }

  static Stream<List<VendorModel>> streamVendorsByStatus(String status) {
    return _col.where('status', isEqualTo: status).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => VendorModel.fromFirestore(doc)).toList());
  }
}
