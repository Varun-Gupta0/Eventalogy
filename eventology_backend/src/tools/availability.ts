import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { db } from "../config/firebase";

// ─── Check Venue Availability ─────────────────────────────────────────────────
// Checks allocations + bookings for a venue on a given date to detect conflicts

export const checkVenueAvailabilityTool = tool(
  async ({ venueId, dateStr }) => {
    try {
      // Parse the date and compute day window
      const targetDate = new Date(dateStr);
      const dayStart = new Date(targetDate);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(targetDate);
      dayEnd.setHours(23, 59, 59, 999);

      // Check bookings collection for venue conflicts
      const bookingSnap = await db.collection("bookings")
        .where("venueId", "==", venueId)
        .where("status", "in", ["confirmed", "pending"])
        .get();

      const conflictingBookings = bookingSnap.docs.filter(doc => {
        const d = doc.data();
        const bookingDate: Date = d.bookingDate?.toDate?.() ?? new Date(d.bookingDate);
        return bookingDate >= dayStart && bookingDate <= dayEnd;
      });

      // Check allocations collection
      const allocSnap = await db.collection("allocations")
        .where("venueId", "==", venueId)
        .where("status", "in", ["confirmed", "pending"])
        .get();

      const conflictingAllocs = allocSnap.docs.filter(doc => {
        const d = doc.data();
        const start: Date = d.startTime?.toDate?.() ?? new Date(d.startTime);
        return start >= dayStart && start <= dayEnd;
      });

      const available = conflictingBookings.length === 0 && conflictingAllocs.length === 0;

      return JSON.stringify({
        venueId,
        date: dateStr,
        available,
        conflictingBookingCount: conflictingBookings.length,
        conflictingAllocationCount: conflictingAllocs.length,
        conflictingBookingIds: conflictingBookings.map(d => d.id),
        conflictingAllocationIds: conflictingAllocs.map(d => d.id),
      });
    } catch (err: any) {
      return JSON.stringify({ error: `Venue availability check failed: ${err.message}` });
    }
  },
  {
    name: "check_venue_availability",
    description: "Check if a specific venue is available on a given date by querying existing bookings and allocations. Returns availability status and any conflicting record IDs.",
    schema: z.object({
      venueId: z.string().describe("The Firestore venue document ID to check"),
      dateStr: z.string().describe("The event date in ISO format (e.g. 2025-12-20)"),
    }),
  }
);

// ─── Check Vendor Availability ────────────────────────────────────────────────

export const checkVendorAvailabilityTool = tool(
  async ({ vendorId, dateStr }) => {
    try {
      const targetDate = new Date(dateStr);
      const dayStart = new Date(targetDate);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(targetDate);
      dayEnd.setHours(23, 59, 59, 999);

      // Check bookings
      const bookingSnap = await db.collection("bookings")
        .where("vendorId", "==", vendorId)
        .where("status", "in", ["confirmed", "pending"])
        .get();

      const conflictingBookings = bookingSnap.docs.filter(doc => {
        const d = doc.data();
        const bookingDate: Date = d.bookingDate?.toDate?.() ?? new Date(d.bookingDate);
        return bookingDate >= dayStart && bookingDate <= dayEnd;
      });

      // Check allocations
      const allocSnap = await db.collection("allocations")
        .where("vendorId", "==", vendorId)
        .where("status", "in", ["confirmed", "pending"])
        .get();

      const conflictingAllocs = allocSnap.docs.filter(doc => {
        const d = doc.data();
        const start: Date = d.startTime?.toDate?.() ?? new Date(d.startTime);
        return start >= dayStart && start <= dayEnd;
      });

      const available = conflictingBookings.length === 0 && conflictingAllocs.length === 0;

      return JSON.stringify({
        vendorId,
        date: dateStr,
        available,
        conflictingBookingCount: conflictingBookings.length,
        conflictingAllocationCount: conflictingAllocs.length,
        conflictingBookingIds: conflictingBookings.map(d => d.id),
      });
    } catch (err: any) {
      return JSON.stringify({ error: `Vendor availability check failed: ${err.message}` });
    }
  },
  {
    name: "check_vendor_availability",
    description: "Check if a specific vendor is available on a given date by querying existing bookings and allocations.",
    schema: z.object({
      vendorId: z.string().describe("The Firestore vendor document ID to check"),
      dateStr: z.string().describe("The event date in ISO format"),
    }),
  }
);
