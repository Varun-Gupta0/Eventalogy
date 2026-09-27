import '../../models/planner/models.dart';

class PlannerMockData {
  static final eventTypes = [
    EventType(id: '1', name: 'Wedding', imageUrl: 'assets/wedding.jpg'),
    EventType(id: '2', name: 'Corporate', imageUrl: 'assets/corporate.jpg'),
    EventType(id: '3', name: 'Celebration', imageUrl: 'assets/celebration.jpg'),
  ];

  static final packages = [
    Package(id: 'p1', eventTypeId: '1', name: 'Silver Wedding', price: 5000, description: 'Basic package'),
    Package(id: 'p2', eventTypeId: '1', name: 'Gold Wedding', price: 10000, description: 'Premium package'),
    Package(id: 'p3', eventTypeId: '2', name: 'Conference Pro', price: 15000, description: 'For up to 500 attendees'),
  ];

  static final vendors = [
    Vendor(id: 'v1', eventTypeId: '1', name: 'Grand Venue', category: 'Venue'),
    Vendor(id: 'v2', eventTypeId: '1', name: 'SnapStudio', category: 'Photography'),
  ];
}
