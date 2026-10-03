# Phase 21A Initial Error Inventory

| Error | File | Line | Root Cause | Planned Fix |
| :--- | :--- | :--- | :--- | :--- |
| Classes can't be declared inside other classes | `chat_components.dart` | 358, 436 | `AIChatInputBox` and `ErrorMessageCard` are nested inside another class accidentally | Move these classes to the top level |
| Target of URI doesn't exist: `categories_mock_data.dart` | `category_listing_screen.dart`, `user_categories_view.dart` | 2, 3 | The mock data file was deleted in previous phases | Migrate these screens to use `CatalogRepository` or comment out/remove the stale references if unused |
| The method `getEvent` isn't defined | `event_detail_screen.dart` | 36 | Missing contract in `EventsRepository` | Implement `getEvent(String eventId)` in `EventsRepository` |
| The method `streamUserEvents` isn't defined | `my_events_screen.dart` | 45 | Missing contract in `EventsRepository` | Implement `streamUserEvents(String userId)` in `EventsRepository` |
| The getter `userId` isn't defined | `my_events_screen.dart` | 14 | `AuthStateNotifier` is missing a `userId` getter | Add `String? get userId` to `AuthStateNotifier` |
| The method `getEventType` isn't defined | `event_planner_screen.dart` | 45 | Missing contract in `CatalogRepository` | Implement `getEventType(String id)` in `CatalogRepository` |
| Target of URI doesn't exist: `booking_model.dart` | `vendor_bookings_view.dart` | 5 | `BookingModel` is completely missing | Create `BookingModel` matching Firestore structure |
| Target of URI doesn't exist: `enquiry_model.dart` | `vendor_enquiries_view.dart` | 5 | `EnquiryModel` is completely missing | Create `EnquiryModel` matching Firestore structure |
| The getter `id` isn't defined for `VendorModel` | `vendor_bookings_view.dart`, `vendor_dashboard_view.dart`, etc | Multiple | `VendorModel` is missing `id` (or uses `vendorId`) | Check `VendorModel` and add `id` getter alias to `vendorId` |
| The getter `mediaGallery` isn't defined | `vendor_profile_view.dart`, `vendor_dashboard_view.dart` | Multiple | `VendorModel` is missing UI fields | Add `mediaGallery`, `vendorType`, `basePrice` to `VendorModel` |
| The property `status` can't be unconditionally accessed | `vendor_bookings_view.dart` | 58 | `null` safety issue | Use `?.status` or `??` |
