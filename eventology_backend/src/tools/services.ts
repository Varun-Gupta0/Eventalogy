import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { db } from "../config/firebase";

// ─── Get Services by Category ─────────────────────────────────────────────────

export const getServicesByCategoryTool = tool(
  async ({ categoryName }) => {
    try {
      let catQuery = db.collection("categories").where("active", "==", true);
      if (categoryName) catQuery = catQuery.where("name", "==", categoryName) as any;

      const catSnap = await catQuery.get();
      if (catSnap.empty) return JSON.stringify({ error: `Category '${categoryName}' not found.` });

      const results: any[] = [];
      for (const catDoc of catSnap.docs) {
        const servSnap = await db.collection("services")
          .where("categoryId", "==", catDoc.id)
          .where("active", "==", true)
          .get();
        results.push({
          categoryId: catDoc.id,
          categoryName: catDoc.data().name,
          services: servSnap.docs.map(s => ({ serviceId: s.id, name: s.data().name, description: s.data().description })),
        });
      }
      return JSON.stringify(results);
    } catch (err: any) {
      return JSON.stringify({ error: `Services fetch failed: ${err.message}` });
    }
  },
  {
    name: "get_services_by_category",
    description: "Get all services available within a specific category in Eventology. Returns service IDs needed for booking.",
    schema: z.object({
      categoryName: z.string().optional().describe("Category name to filter by. If omitted, returns all categories."),
    }),
  }
);

// ─── Get Packages ─────────────────────────────────────────────────────────────

export const getPackagesTool = tool(
  async ({ eventType }) => {
    try {
      let query: FirebaseFirestore.Query = db.collection("packages").where("active", "==", true);
      if (eventType) query = query.where("eventType", "==", eventType);

      const snapshot = await query.limit(10).get();
      const packages = snapshot.docs.map(doc => ({
        packageId: doc.id,
        ...doc.data(),
      }));
      return JSON.stringify(packages.length > 0 ? packages : { message: "No packages found." });
    } catch (err: any) {
      return JSON.stringify({ error: `Packages fetch failed: ${err.message}` });
    }
  },
  {
    name: "get_packages",
    description: "Get bundled event packages available in Eventology. Useful when the user wants an all-in-one option.",
    schema: z.object({
      eventType: z.string().optional().describe("Filter packages by event type e.g. Wedding, Birthday"),
    }),
  }
);

// ─── Get Package Pricing ──────────────────────────────────────────────────────

export const getPackagePricingTool = tool(
  async ({ packageId }) => {
    try {
      const doc = await db.collection("packages").doc(packageId).get();
      if (!doc.exists) return JSON.stringify({ error: `Package ${packageId} not found.` });
      const d = doc.data()!;
      return JSON.stringify({ packageId, name: d.name, price: d.price, inclusions: d.inclusions ?? [] });
    } catch (err: any) {
      return JSON.stringify({ error: `Package pricing fetch failed: ${err.message}` });
    }
  },
  {
    name: "get_package_pricing",
    description: "Get pricing details for a specific event package.",
    schema: z.object({ packageId: z.string().describe("Firestore package document ID") }),
  }
);

// ─── Get All Categories ───────────────────────────────────────────────────────

export const getAllCategoriesTool = tool(
  async () => {
    try {
      const snapshot = await db.collection("categories").where("active", "==", true).get();
      return JSON.stringify(snapshot.docs.map(d => ({ categoryId: d.id, name: d.data().name })));
    } catch (err: any) {
      return JSON.stringify({ error: `Categories fetch failed: ${err.message}` });
    }
  },
  {
    name: "get_all_categories",
    description: "Get all active service categories available in Eventology.",
    schema: z.object({}),
  }
);

// ─── Get Event Types ──────────────────────────────────────────────────────────

export const getEventTypesTool = tool(
  async () => {
    try {
      const snapshot = await db.collection("eventTypes").where("active", "==", true).get();
      return JSON.stringify(snapshot.docs.map(d => ({ eventTypeId: d.id, name: d.data().name })));
    } catch (err: any) {
      return JSON.stringify({ error: `Event types fetch failed: ${err.message}` });
    }
  },
  {
    name: "get_event_types",
    description: "Get all valid event types in Eventology (e.g., Wedding, Birthday, Corporate).",
    schema: z.object({}),
  }
);

// ─── Get Locations ────────────────────────────────────────────────────────────

export const getLocationsTool = tool(
  async () => {
    try {
      const snapshot = await db.collection("locations").where("active", "==", true).get();
      return JSON.stringify(snapshot.docs.map(d => ({ locationId: d.id, city: d.data().city, state: d.data().state })));
    } catch (err: any) {
      return JSON.stringify({ error: `Locations fetch failed: ${err.message}` });
    }
  },
  {
    name: "get_locations",
    description: "Get all active supported cities and locations in Eventology.",
    schema: z.object({}),
  }
);
