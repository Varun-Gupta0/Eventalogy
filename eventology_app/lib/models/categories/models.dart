class EventCategory {
  final String id;
  final String name;
  final String iconAsset;

  EventCategory({required this.id, required this.name, required this.iconAsset});
}

abstract class ServiceListing {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final double price;
  final String type;

  ServiceListing({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    required this.type,
  });
}

class VenueListing extends ServiceListing {
  final int capacity;

  VenueListing({
    required super.id,
    required super.categoryId,
    required super.title,
    required super.description,
    required super.price,
    required this.capacity,
  }) : super(type: 'Venue');
}

class ArtistListing extends ServiceListing {
  final String genre;

  ArtistListing({
    required super.id,
    required super.categoryId,
    required super.title,
    required super.description,
    required super.price,
    required this.genre,
  }) : super(type: 'Artist');
}
