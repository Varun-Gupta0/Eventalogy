/// Centralized Firestore collection name constants.
///
/// ALL Firestore collection references in this application MUST use these
/// constants. Do NOT hardcode collection name strings anywhere else.
///
/// This file is the single source of truth for the Eventology ERP collection
/// names against the `user-data` Firestore database.

class Collections {
  Collections._(); // Prevent instantiation

  // ── MASTER DATA ──────────────────────────────────────────────────────────
  static const String users = 'users';
  static const String venues = 'venues';
  static const String vendors = 'vendors';
  static const String services = 'services';
  static const String packages = 'packages';
  static const String categories = 'categories';
  static const String eventTypes = 'eventTypes';
  static const String locations = 'locations';
  static const String venueTypes = 'venueTypes';

  // ── TRANSACTION DATA ──────────────────────────────────────────────────────
  static const String events = 'events';
  static const String enquiries = 'enquiries';
  static const String bookings = 'bookings';
  static const String allocations = 'allocations';
  static const String payments = 'payments';
  static const String reviews = 'reviews';

  // ── AI DATA ───────────────────────────────────────────────────────────────
  static const String aiPlans = 'ai_plans';
  static const String aiRecommendations = 'ai_recommendations';
  static const String agentTasks = 'agent_tasks';
  static const String agentLogs = 'agent_logs';

  // ── SYSTEM DATA ───────────────────────────────────────────────────────────
  static const String notifications = 'notifications';
  static const String auditLogs = 'audit_logs';
  static const String settings = 'settings';
}
