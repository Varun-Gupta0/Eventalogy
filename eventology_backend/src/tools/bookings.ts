import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { db } from "../config/firebase";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

// ─── Create Enquiry ────────────────────────────────────────────────────────────
// Signals vendor intent before committing a booking

export const createEnquiryTool = tool(
  async ({ eventId, customerId, vendorId, serviceId, message, requestedDateStr }) => {
    try {
      const ref = db.collection("enquiries").doc();
      await ref.set({
        enquiryId: ref.id,
        eventId,
        customerId,
        vendorId,
        serviceId,
        message,
        requirements: {},
        requestedDate: Timestamp.fromDate(new Date(requestedDateStr)),
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });
      return JSON.stringify({ success: true, enquiryId: ref.id });
    } catch (err: any) {
      return JSON.stringify({ error: `Create enquiry failed: ${err.message}` });
    }
  },
  {
    name: "create_enquiry",
    description: "Create an enquiry record to signal intent to a vendor before creating a booking. Returns the enquiry ID.",
    schema: z.object({
      eventId: z.string().describe("The Firestore event ID"),
      customerId: z.string().describe("The customer (user) ID"),
      vendorId: z.string().describe("The target vendor ID"),
      serviceId: z.string().describe("The specific service ID being enquired about"),
      message: z.string().describe("A human-readable enquiry message"),
      requestedDateStr: z.string().describe("The requested service date in ISO format"),
    }),
  }
);

// ─── Create Booking ────────────────────────────────────────────────────────────
// WRITE tool — only called by booking_agent after approval is verified

export const createBookingTool = tool(
  async ({ eventId, customerId, vendorId, serviceId, venueId, amount, bookingDateStr, packageId }) => {
    try {
      const ref = db.collection("bookings").doc();
      await ref.set({
        bookingId: ref.id,
        eventId,
        customerId,
        vendorId,
        serviceId,
        venueId: venueId ?? null,
        packageId: packageId ?? null,
        amount,
        status: "pending",
        paymentStatus: "unpaid",
        bookingDate: Timestamp.fromDate(new Date(bookingDateStr)),
        createdAt: FieldValue.serverTimestamp(),
      });
      return JSON.stringify({ success: true, bookingId: ref.id });
    } catch (err: any) {
      return JSON.stringify({ error: `Create booking failed: ${err.message}` });
    }
  },
  {
    name: "create_booking",
    description: "Create a booking record in Firestore. ONLY call this after user approval has been verified. Returns the booking ID.",
    schema: z.object({
      eventId: z.string().describe("The Firestore event ID"),
      customerId: z.string().describe("The customer (user) ID"),
      vendorId: z.string().describe("The vendor ID being booked"),
      serviceId: z.string().describe("The service ID"),
      venueId: z.string().optional().describe("The venue ID if applicable"),
      amount: z.number().describe("Booking amount in INR"),
      bookingDateStr: z.string().describe("The booking date in ISO format"),
      packageId: z.string().optional().describe("Package ID if booking a package"),
    }),
  }
);

// ─── Create Allocation ─────────────────────────────────────────────────────────
// Links a venue/vendor to an event for a time slot

export const createAllocationTool = tool(
  async ({ eventId, vendorId, venueId, serviceId, assignedBy, startTimeStr, endTimeStr }) => {
    try {
      const ref = db.collection("allocations").doc();
      await ref.set({
        allocationId: ref.id,
        eventId,
        vendorId: vendorId ?? null,
        venueId: venueId ?? null,
        serviceId: serviceId ?? null,
        assignedBy,
        status: "confirmed",
        startTime: Timestamp.fromDate(new Date(startTimeStr)),
        endTime: Timestamp.fromDate(new Date(endTimeStr)),
        createdAt: FieldValue.serverTimestamp(),
      });
      return JSON.stringify({ success: true, allocationId: ref.id });
    } catch (err: any) {
      return JSON.stringify({ error: `Create allocation failed: ${err.message}` });
    }
  },
  {
    name: "create_allocation",
    description: "Create an allocation record linking a venue or vendor to an event for a specific time slot. ONLY call after user approval.",
    schema: z.object({
      eventId: z.string().describe("The event ID"),
      vendorId: z.string().optional().describe("Vendor ID (if allocating a vendor)"),
      venueId: z.string().optional().describe("Venue ID (if allocating a venue)"),
      serviceId: z.string().optional().describe("Service ID if relevant"),
      assignedBy: z.string().describe("The agent or user ID assigning this allocation"),
      startTimeStr: z.string().describe("Start time of the allocation in ISO format"),
      endTimeStr: z.string().describe("End time of the allocation in ISO format"),
    }),
  }
);

// ─── Create Notification ──────────────────────────────────────────────────────

export const createNotificationTool = tool(
  async ({ userId, type, title, message, metadata }) => {
    try {
      const ref = db.collection("notifications").doc();
      await ref.set({
        notificationId: ref.id,
        userId,
        type,
        title,
        message,
        isRead: false,
        metadata: metadata ?? {},
        createdAt: FieldValue.serverTimestamp(),
      });
      return JSON.stringify({ success: true, notificationId: ref.id });
    } catch (err: any) {
      return JSON.stringify({ error: `Create notification failed: ${err.message}` });
    }
  },
  {
    name: "create_notification",
    description: "Create a notification record in Firestore for a user. Used to inform customers and vendors about booking updates.",
    schema: z.object({
      userId: z.string().describe("The recipient user ID"),
      type: z.string().describe("Notification type e.g. booking_confirmed, enquiry_sent, approval_required"),
      title: z.string().describe("Short notification title"),
      message: z.string().describe("Full notification message body"),
      metadata: z.record(z.string(), z.any()).optional().describe("Optional metadata (bookingId, vendorId, etc.)"),
    }),
  }
);

// ─── Get Event by ID ──────────────────────────────────────────────────────────

export const getEventTool = tool(
  async ({ eventId }) => {
    try {
      const doc = await db.collection("events").doc(eventId).get();
      if (!doc.exists) return JSON.stringify({ error: `Event ${eventId} not found.` });
      return JSON.stringify({ eventId: doc.id, ...doc.data() });
    } catch (err: any) {
      return JSON.stringify({ error: `Get event failed: ${err.message}` });
    }
  },
  {
    name: "get_event",
    description: "Retrieve event details from Firestore by event ID.",
    schema: z.object({ eventId: z.string().describe("The Firestore event document ID") }),
  }
);
