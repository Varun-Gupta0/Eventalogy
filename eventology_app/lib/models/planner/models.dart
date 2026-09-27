class EventType {
  final String id;
  final String name;
  final String imageUrl;

  EventType({required this.id, required this.name, required this.imageUrl});
}

class Package {
  final String id;
  final String eventTypeId;
  final String name;
  final double price;
  final String description;

  Package({
    required this.id,
    required this.eventTypeId,
    required this.name,
    required this.price,
    required this.description,
  });
}

class Vendor {
  final String id;
  final String eventTypeId;
  final String name;
  final String category;

  Vendor({
    required this.id,
    required this.eventTypeId,
    required this.name,
    required this.category,
  });
}
