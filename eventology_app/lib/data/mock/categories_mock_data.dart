import '../../models/categories/models.dart';

class CategoriesMockData {
  static final categories = List.generate(20, (index) => EventCategory(
    id: 'c$index',
    name: 'Category $index',
    iconAsset: 'assets/cat$index.png',
  ));

  static final listings = [
    VenueListing(
      id: 'l1',
      categoryId: 'c0',
      title: 'Grand Palace',
      description: 'Luxury venue for large events',
      price: 20000,
      capacity: 1000,
    ),
    ArtistListing(
      id: 'l2',
      categoryId: 'c1',
      title: 'The Rockers',
      description: 'Live band',
      price: 5000,
      genre: 'Rock',
    ),
  ];
}
