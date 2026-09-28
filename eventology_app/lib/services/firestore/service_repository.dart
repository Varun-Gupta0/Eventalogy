import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firestore_config.dart';
import '../../core/database/collections.dart';
import '../../models/service_model.dart';

class ServiceRepository {
  static final FirebaseFirestore _db = FirestoreConfig.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.services);

  static void _validateService(ServiceModel service) {
    if (service.name.trim().isEmpty) {
      throw ArgumentError('Service name is required');
    }
    if (service.categoryId.trim().isEmpty) {
      throw ArgumentError('Category ID is required');
    }
    if (service.pricingModel.trim().isEmpty) {
      throw ArgumentError('Pricing model is required');
    }
  }

  static Future<ServiceModel> createService(ServiceModel service) async {
    _validateService(service);
    final docRef = _col.doc();
    
    final newService = ServiceModel(
      serviceId: docRef.id,
      name: service.name,
      categoryId: service.categoryId,
      subcategoryId: service.subcategoryId,
      description: service.description,
      pricingModel: service.pricingModel,
      basePrice: service.basePrice,
      images: service.images,
      active: service.active,
      createdAt: Timestamp.now(),
    );

    await docRef.set(newService.toFirestore());
    return newService;
  }

  static Future<ServiceModel?> getService(String serviceId) async {
    final doc = await _col.doc(serviceId).get();
    if (!doc.exists) return null;
    return ServiceModel.fromFirestore(doc);
  }

  static Future<void> updateService(ServiceModel service) async {
    if (service.serviceId.isEmpty) {
      throw ArgumentError('Service ID is required for updates');
    }
    _validateService(service);
    
    final updates = service.toFirestore();
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    await _col.doc(service.serviceId).update(updates);
  }

  static Future<void> deleteService(String serviceId) async {
    await _col.doc(serviceId).delete();
  }

  static Stream<List<ServiceModel>> streamServices() {
    return _col.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList();
    });
  }

  /// One-time business-data seed for initial Eventology service catalog.
  /// Idempotent: checks if services exist by name before creating.
  static Future<Map<String, dynamic>> seedInitialServices() async {
    final Map<String, dynamic> result = {
      'created': 0,
      'skipped': 0,
      'errors': <String>[],
    };

    final batch = _db.batch();
    
    // Fetch categories to map by exact name
    final categoriesSnap = await _db.collection(Collections.categories).get();
    final Map<String, String> categoryMap = {};
    for (var doc in categoriesSnap.docs) {
      final name = doc.data()['name'] as String? ?? '';
      categoryMap[name.toLowerCase()] = doc.id;
    }

    // Fetch existing services by name to avoid duplicates
    final servicesSnap = await _col.get();
    final Set<String> existingServiceNames = servicesSnap.docs
        .map((doc) => (doc.data()['name'] as String? ?? '').toLowerCase())
        .toSet();

    final standardServices = [
      {'name': 'Event Photography', 'category': 'Photography', 'pricing': 'custom', 'desc': 'Professional event photography services.'},
      {'name': 'Videography', 'category': 'Photography', 'pricing': 'custom', 'desc': 'High-quality videography and cinematography.'},
      {'name': 'Full-Service Catering', 'category': 'Catering', 'pricing': 'per_person', 'desc': 'Comprehensive food and beverage catering.'},
      {'name': 'Buffet Catering', 'category': 'Catering', 'pricing': 'per_person', 'desc': 'Self-serve buffet style catering.'},
      {'name': 'Event Decoration', 'category': 'Decoration', 'pricing': 'custom', 'desc': 'Complete venue styling and decoration.'},
      {'name': 'Floral Decoration', 'category': 'Decoration', 'pricing': 'custom', 'desc': 'Specialized floral arrangements.'},
      {'name': 'DJ Services', 'category': 'Entertainment', 'pricing': 'custom', 'desc': 'Professional DJ and sound setup.'},
      {'name': 'Live Band', 'category': 'Entertainment', 'pricing': 'custom', 'desc': 'Live music performances.'},
      {'name': 'Event Makeup', 'category': 'Beauty', 'pricing': 'custom', 'desc': 'Professional makeup artist services.'},
      {'name': 'Hairstyling', 'category': 'Beauty', 'pricing': 'custom', 'desc': 'Expert hair styling services.'},
      {'name': 'Guest Transportation', 'category': 'Transportation', 'pricing': 'custom', 'desc': 'Fleet and shuttle services for guests.'},
      {'name': 'Luxury Car Rental', 'category': 'Transportation', 'pricing': 'custom', 'desc': 'Premium vehicles for special entry/exit.'},
      {'name': 'Digital Invitations', 'category': 'Invitation', 'pricing': 'custom', 'desc': 'Custom e-invites and RSVP tracking.'},
      {'name': 'Printed Invitations', 'category': 'Invitation', 'pricing': 'custom', 'desc': 'Premium physical invitation cards.'},
    ];

    for (final s in standardServices) {
      if (existingServiceNames.contains(s['name']!.toLowerCase())) {
        result['skipped'] = (result['skipped'] as int) + 1;
        continue;
      }

      final catName = s['category']!;
      final catId = categoryMap[catName.toLowerCase()];
      
      if (catId == null) {
        (result['errors'] as List<String>).add('Category not found: \$catName');
        continue;
      }

      final ref = _col.doc();
      batch.set(ref, {
        'serviceId': ref.id,
        'name': s['name'],
        'categoryId': catId,
        'description': s['desc'],
        'pricingModel': s['pricing'],
        'images': <String>[],
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      result['created'] = (result['created'] as int) + 1;
    }

    if ((result['created'] as int) > 0) {
      await batch.commit();
    }
    
    return result;
  }
}
