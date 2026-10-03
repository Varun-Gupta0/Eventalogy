import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { db } from "../config/firebase";

// ─── Venue Search ─────────────────────────────────────────────────────────────

export const searchVenuesTool = tool(
  async ({ city, minCapacity, maxCapacity, venueType }) => {
    try {
      let query: FirebaseFirestore.Query = db.collection("venues").where("status", "==", "active").where("verified", "==", true);
      // locationId would be used instead of city, but for now we skip filtering by city directly in DB if we don't have locationId
      // if (city) query = query.where("city", "==", city);
      if (venueType) query = query.where("venueTypeId", "==", venueType);

      const snapshot = await query.limit(20).get();
      const venues = snapshot.docs
        .map(doc => {
          const d = doc.data();
          return {
            venueId: doc.id,
            name: d.name,
            locationId: d.locationId,
            capacity: d.capacity,
            venueType: d.venueTypeId,
            basePrice: d.priceFrom,
            amenities: d.amenities || [],
            description: d.description,
          };
        })
        .filter(v =>
          (minCapacity == null || v.capacity >= minCapacity) &&
          (maxCapacity == null || v.capacity <= maxCapacity)
        );

      return JSON.stringify(venues.length > 0 ? venues : { message: "No venues found matching criteria." });
    } catch (err: any) {
      return JSON.stringify({ error: `Venue search failed: ${err.message}` });
    }
  },
  {
    name: "search_venues",
    description: "Search for venues in Eventology by city, capacity range, and venue type. Returns a list of matching venues with capacity and pricing.",
    schema: z.object({
      city: z.string().optional().describe("City name to filter by"),
      minCapacity: z.number().optional().describe("Minimum guest capacity required"),
      maxCapacity: z.number().optional().describe("Maximum guest capacity needed"),
      venueType: z.string().optional().describe("Type of venue e.g. banquet hall, outdoor, hotel"),
    }),
  }
);

// ─── Venue Detail ─────────────────────────────────────────────────────────────

export const getVenueDetailsTool = tool(
  async ({ venueId }) => {
    try {
      const doc = await db.collection("venues").doc(venueId).get();
      if (!doc.exists) return JSON.stringify({ error: `Venue ${venueId} not found.` });
      return JSON.stringify({ venueId: doc.id, ...doc.data() });
    } catch (err: any) {
      return JSON.stringify({ error: `Failed to get venue: ${err.message}` });
    }
  },
  {
    name: "get_venue_details",
    description: "Retrieve full details for a specific venue by its Firestore ID.",
    schema: z.object({ venueId: z.string().describe("The Firestore document ID of the venue") }),
  }
);

// ─── Venue Pricing ────────────────────────────────────────────────────────────

export const getVenuePricingTool = tool(
  async ({ venueId }) => {
    try {
      const doc = await db.collection("venues").doc(venueId).get();
      if (!doc.exists) return JSON.stringify({ error: `Venue ${venueId} not found.` });
      const d = doc.data()!;
      return JSON.stringify({
        venueId,
        name: d.name,
        basePrice: d.basePrice ?? null,
        pricingModel: d.pricingModel ?? "per_event",
        notes: d.pricingNotes ?? null,
      });
    } catch (err: any) {
      return JSON.stringify({ error: `Failed to get venue pricing: ${err.message}` });
    }
  },
  {
    name: "get_venue_pricing",
    description: "Get pricing information for a specific venue.",
    schema: z.object({ venueId: z.string().describe("The Firestore venue ID") }),
  }
);
