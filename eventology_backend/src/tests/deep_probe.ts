import { db } from "../config/firebase";

async function deepProbe() {
  console.log("=== DEEP DATA PROBE ===\n");

  // All services
  console.log("── All services ──");
  const services = await db.collection("services").get();
  services.docs.forEach(d => {
    const data = d.data();
    console.log(JSON.stringify({ id: d.id, name: data.name, categoryId: data.categoryId, price: data.price, basePrice: data.basePrice, description: data.description?.substring(0, 60) }));
  });

  // All categories
  console.log("\n── All categories ──");
  const cats = await db.collection("categories").get();
  cats.docs.forEach(d => {
    const data = d.data();
    console.log(JSON.stringify({ id: d.id, name: data.name, type: data.type, description: data.description?.substring(0, 60) }));
  });

  // locations
  console.log("\n── All locations ──");
  const locs = await db.collection("locations").get();
  locs.docs.forEach(d => {
    console.log(JSON.stringify({ id: d.id, ...d.data() }));
  });

  // users collection
  console.log("\n── users collection ──");
  try {
    const users = await db.collection("users").limit(5).get();
    console.log(`users count: ${users.size}`);
    users.docs.forEach(d => {
      const data = d.data();
      console.log(JSON.stringify({ id: d.id, email: data.email, role: data.role, displayName: data.displayName }));
    });
  } catch (e: any) { console.log(`users error: ${e.message}`); }

  process.exit(0);
}

deepProbe().catch(err => { console.error(err); process.exit(1); });
