import { tool } from "@langchain/core/tools";
import { z } from "zod";
import { db } from "../config/firebase";

export const getEventTypesTool = tool(
  async () => {
    try {
      const snapshot = await db.collection("eventTypes").where("active", "==", true).get();
      const types = snapshot.docs.map(doc => doc.data().name);
      return JSON.stringify(types);
    } catch (error: any) {
      return `Error fetching event types: ${error.message}`;
    }
  },
  {
    name: "get_event_types",
    description: "Returns a list of valid event types available in the Eventology system.",
    schema: z.object({}),
  }
);

export const getServicesTool = tool(
  async () => {
    try {
      const snapshot = await db.collection("categories").where("active", "==", true).get();
      const services = snapshot.docs.map(doc => doc.data().name);
      return JSON.stringify(services);
    } catch (error: any) {
      return `Error fetching services: ${error.message}`;
    }
  },
  {
    name: "get_services",
    description: "Returns a list of available service categories in Eventology.",
    schema: z.object({}),
  }
);

export const getLocationsTool = tool(
  async () => {
    try {
      const snapshot = await db.collection("locations").where("active", "==", true).get();
      const locations = snapshot.docs.map(doc => doc.data().city);
      return JSON.stringify(locations);
    } catch (error: any) {
      return `Error fetching locations: ${error.message}`;
    }
  },
  {
    name: "get_locations",
    description: "Returns a list of supported cities/locations.",
    schema: z.object({}),
  }
);
