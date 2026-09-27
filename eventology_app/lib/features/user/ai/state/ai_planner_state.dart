import '../../../../models/ai/models.dart';

class AIPlannerState {
  static final AIPlannerState _instance = AIPlannerState._internal();
  factory AIPlannerState() => _instance;
  AIPlannerState._internal();

  AIEventPlanRequest currentRequest = AIEventPlanRequest();

  void reset() {
    currentRequest = AIEventPlanRequest();
  }
}
