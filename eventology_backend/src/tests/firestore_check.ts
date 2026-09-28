import { db } from "../config/firebase";
import * as dotenv from "dotenv";

dotenv.config({ override: true });

async function checkFirestore() {
  console.log("=== FIRESTORE DATASET AUDIT ===");
  const collections = ["venues", "vendors", "services", "events", "users", "agent_tasks", "checkpoints", "enquiries", "bookings", "allocations"];

  for (const colName of collections) {
    try {
      const snap = await db.collection(colName).limit(10).get();
      console.log(`Collection '${colName}': ${snap.size} documents found (checked top 10 limit)`);
      if (snap.size > 0) {
        const sample = snap.docs[0].data();
        console.log(`  Sample doc ID '${snap.docs[0].id}':`, Object.keys(sample));
      }
    } catch (err: any) {
      console.error(`Error querying collection '${colName}':`, err.message);
    }
  }
}

checkFirestore().then(() => process.exit(0)).catch(console.error);
