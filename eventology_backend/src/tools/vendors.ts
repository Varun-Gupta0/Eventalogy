import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { db } from "../config/firebase";

// ─── Vendor Search by Service Category ───────────────────────────────────────

export const searchVendorsByServiceTool = tool(
  async ({ serviceCategory, city }) => {
    try {
      // First resolve the category to its ID
      const catSnap = await db.collection("categories")
        .where("name", "==", serviceCategory)
        .where("active", "==", true)
        .limit(1).get();

      let query: FirebaseFirestore.Query = db.collection("vendors").where("status", "==", "active");
      if (!catSnap.empty) {
        query = query.where("categoryIds", "array-contains", catSnap.docs[0].id);
      }
      // locationId would be used instead of city
      // if (city) query = query.where("city", "==", city);

      const snapshot = await query.limit(15).get();
      const vendors = snapshot.docs.map(doc => {
        const d = doc.data();
        return {
          vendorId: doc.id,
          name: d.businessName,
          serviceCategory,
          categoryIds: d.categoryIds,
          locationId: d.locationId,
          rating: d.rating,
          pricingModel: d.pricingModel,
          description: d.description,
          portfolioImages: d.portfolioImages ?? [],
        };
      });

      return JSON.stringify(vendors.length > 0 ? vendors : { message: `No vendors found for ${serviceCategory} in ${city ?? "any city"}.` });
    } catch (err: any) {
      return JSON.stringify({ error: `Vendor search failed: ${err.message}` });
    }
  },
  {
    name: "search_vendors_by_service",
    description: "Search vendors in Eventology by service category (e.g., Catering, Photography, Decoration) and optionally filter by city.",
    schema: z.object({
      serviceCategory: z.string().describe("The service category name e.g. Catering, Photography, DJ, Decoration"),
      city: z.string().optional().describe("City to filter vendors by"),
    }),
  }
);

// ─── Vendor Detail ────────────────────────────────────────────────────────────

export const getVendorDetailsTool = tool(
  async ({ vendorId }) => {
    try {
      const doc = await db.collection("vendors").doc(vendorId).get();
      if (!doc.exists) return JSON.stringify({ error: `Vendor ${vendorId} not found.` });
      return JSON.stringify({ vendorId: doc.id, ...doc.data() });
    } catch (err: any) {
      return JSON.stringify({ error: `Failed to get vendor: ${err.message}` });
    }
  },
  {
    name: "get_vendor_details",
    description: "Retrieve full details for a specific vendor by their Firestore ID.",
    schema: z.object({ vendorId: z.string().describe("The Firestore document ID of the vendor") }),
  }
);

// ─── Vendor Pricing ───────────────────────────────────────────────────────────

export const getVendorPricingTool = tool(
  async ({ vendorId }) => {
    try {
      const doc = await db.collection("vendors").doc(vendorId).get();
      if (!doc.exists) return JSON.stringify({ error: `Vendor ${vendorId} not found.` });
      const d = doc.data()!;
      return JSON.stringify({
        vendorId,
        name: d.name,
        priceRange: d.priceRange ?? null,
        basePrice: d.basePrice ?? null,
        pricingModel: d.pricingModel ?? "per_event",
        notes: d.pricingNotes ?? null,
      });
    } catch (err: any) {
      return JSON.stringify({ error: `Failed to get vendor pricing: ${err.message}` });
    }
  },
  {
    name: "get_vendor_pricing",
    description: "Get pricing information for a specific vendor.",
    schema: z.object({ vendorId: z.string().describe("The Firestore vendor ID") }),
  }
);
