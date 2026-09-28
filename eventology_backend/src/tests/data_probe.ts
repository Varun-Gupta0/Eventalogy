// Data probe using the project's existing firebase config module
import { db } from "../config/firebase";
import { getAuth } from "firebase-admin/auth";

async function probe() {
  const report: any = {};

  const collections = [
    "venues", "vendors", "services", "categories", "packages",
    "events", "enquiries", "bookings", "allocations",
    "locations", "event_types",
    "agent_tasks", "agent_logs", "ai_plans",
  ];

  console.log("Probing Firestore database: user-data\n");

  for (const col of collections) {
    try {
      const snap = await db.collection(col).limit(10).get();
      const docs = snap.docs.map(d => {
        const data = d.data();
        return {
          id: d.id,
          name: data.name ?? data.title ?? data.eventType ?? data.agentType ?? "(unnamed)",
          city: data.city ?? data.location ?? undefined,
          status: data.status ?? undefined,
        };
      });
      report[col] = { count: snap.size, docs };
      console.log(`✓ ${col}: ${snap.size} documents`);
      for (const d of docs.slice(0, 3)) {
        console.log(`   - ${d.id}: ${d.name}${d.city ? ` (${d.city})` : ""}${d.status ? ` [${d.status}]` : ""}`);
      }
    } catch (err: any) {
      report[col] = { error: err.message };
      console.log(`✗ ${col}: ERROR - ${err.message}`);
    }
  }

  // Raipur-specific
  console.log("\n── Raipur venue search ──");
  try {
    const snap = await db.collection("venues").where("city", "==", "Raipur").limit(10).get();
    console.log(`Venues in 'Raipur': ${snap.size}`);
    snap.docs.forEach(d => console.log(`   - ${d.id}: ${d.data().name} (cap: ${d.data().capacity})`));

    const snap2 = await db.collection("venues").where("city", "==", "raipur").limit(5).get();
    console.log(`Venues in 'raipur': ${snap2.size}`);

    report.raipurVenues = snap.size + snap2.size;
  } catch (err: any) {
    console.log(`Raipur search error: ${err.message}`);
  }

  // All venues with city
  console.log("\n── All venues ──");
  try {
    const allVenues = await db.collection("venues").limit(20).get();
    const cities = new Set<string>();
    allVenues.docs.forEach(d => {
      const data = d.data();
      const city = data.city;
      if (city) cities.add(city);
      console.log(`   ${d.id}: ${data.name} — city: "${city}" cap: ${data.capacity}`);
    });
    report.venueCities = [...cities];
    console.log(`\nDistinct venue cities: ${[...cities].join(", ")}`);
  } catch (err: any) {
    console.log(`All venues error: ${err.message}`);
  }

  // Vendors with categories
  console.log("\n── All vendors ──");
  try {
    const allVendors = await db.collection("vendors").limit(20).get();
    allVendors.docs.forEach(d => {
      const data = d.data();
      console.log(`   ${d.id}: ${data.name} — category: "${data.category ?? data.serviceCategory}" city: "${data.city}"`);
    });
  } catch (err: any) {
    console.log(`Vendors error: ${err.message}`);
  }

  // Auth users
  console.log("\n── Firebase Auth Users ──");
  try {
    const auth = getAuth();
    const list = await auth.listUsers(10);
    report.authUsers = list.users.map(u => ({ uid: u.uid, email: u.email }));
    list.users.forEach(u => console.log(`   - ${u.uid}: ${u.email}`));
  } catch (err: any) {
    console.log(`Auth error: ${err.message}`);
    report.authError = err.message;
  }

  const { writeFileSync } = require("fs");
  writeFileSync("data_probe_report.json", JSON.stringify(report, null, 2));
  console.log("\nData probe complete. See data_probe_report.json");
  process.exit(0);
}

probe().catch(err => { console.error(err); process.exit(1); });
