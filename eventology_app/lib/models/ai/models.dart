class AIEventPlanRequest {
  String? eventType;
  String? vision;
  String? location;
  int? guestCount;
  double? budget;
  List<String> requiredServices = [];

  bool get isComplete => eventType != null && vision != null && location != null && guestCount != null && budget != null;
  
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'vision': vision,
      'location': location,
      'guestCount': guestCount,
      'budget': budget,
      'requiredServices': requiredServices,
    };
  }
}

class AIGeneratedPlan {
  final String title;
  final String summary;
  final List<String> recommendedServices;
  final String estimatedTotal;

  AIGeneratedPlan({
    required this.title,
    required this.summary,
    required this.recommendedServices,
    required this.estimatedTotal,
  });
}
