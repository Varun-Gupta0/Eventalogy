import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream Categories
  static Stream<List<Map<String, dynamic>>> getCategories() {
    return _db.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  // Stream Packages
  static Stream<List<Map<String, dynamic>>> getPackages(String categoryId) {
    return _db
        .collection('packages')
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  // Save AI Generated Enquiry
  static Future<void> createEnquiry(Map<String, dynamic> enquiryData) async {
    try {
      await _db.collection('enquiries').add({
        ...enquiryData,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      // Graceful fallback for offline / demo mode
    }
  }

  // Seed sample data into Firestore if empty
  static Future<void> seedInitialData() async {
    try {
      final categoriesSnapshot = await _db.collection('categories').get();
      if (categoriesSnapshot.docs.isEmpty) {
        final initialCategories = [
          {'name': 'Dream Venues', 'icon': 'location_city', 'subtext': 'Luxury banquets, heritage palaces & beach resorts'},
          {'name': 'Elite Decor & Floral', 'icon': 'local_florist', 'subtext': 'Royal mandaps, neon aesthetics & theme styling'},
          {'name': 'Master Photographers', 'icon': 'camera_alt', 'subtext': 'Cinematic wedding films & drone coverage'},
          {'name': 'Catering & Mixology', 'icon': 'restaurant', 'subtext': 'Multi-cuisine buffets & artisanal cocktail bars'},
          {'name': 'Live Bands & DJs', 'icon': 'music_note', 'subtext': 'Sangeet artists, celebrity DJs & orchestra'},
        ];

        for (var cat in initialCategories) {
          await _db.collection('categories').add(cat);
        }
      }
    } catch (_) {}
  }
}
