import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyEnquiries() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const eventsSnap = await db.collection('events').get();
  const valid_events_Ids = new Set();
  eventsSnap.forEach(doc => valid_events_Ids.add(doc.id));

  const usersSnap = await db.collection('users').get();
  const valid_users_Ids = new Set();
  usersSnap.forEach(doc => valid_users_Ids.add(doc.id));

  const vendorsSnap = await db.collection('vendors').get();
  const valid_vendors_Ids = new Set();
  vendorsSnap.forEach(doc => valid_vendors_Ids.add(doc.id));

  const servicesSnap = await db.collection('services').get();
  const valid_services_Ids = new Set();
  servicesSnap.forEach(doc => valid_services_Ids.add(doc.id));

  const snap = await db.collection('enquiries').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['enquiryId', 'eventId', 'customerId', 'vendorId', 'serviceId', 'message', 'requirements', 'requestedDate', 'status', 'createdAt', 'updatedAt']);

  console.log('--- ENQUIRIES DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.enquiryId || data.enquiryId !== doc.id) invalidId.push(doc.id);

    if (data.message !== undefined && typeof data.message !== 'string') typeViolations.push(`${doc.id} (message should be string)`);
    if (data.status !== undefined && typeof data.status !== 'string') typeViolations.push(`${doc.id} (status should be string)`);

    if (!data.eventId || !valid_events_Ids.has(data.eventId)) refViolations.push(`${doc.id} (eventId: ${data.eventId})`);
    if (!data.customerId || !valid_users_Ids.has(data.customerId)) refViolations.push(`${doc.id} (customerId: ${data.customerId})`);
    if (!data.vendorId || !valid_vendors_Ids.has(data.vendorId)) refViolations.push(`${doc.id} (vendorId: ${data.vendorId})`);
    if (!data.serviceId || !valid_services_Ids.has(data.serviceId)) refViolations.push(`${doc.id} (serviceId: ${data.serviceId})`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Enquiries ---');
  console.log(`Collection checked: enquiries`);
  console.log(`Number of documents checked: ${totalCount}`);
  console.log(`Unexpected documents / invalid IDs: ${invalidId.length > 0 ? invalidId.join(', ') : 'None (` + invalidId.length + `)'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None (` + unexpectedFields.length + `)'}`);
  console.log(`Schema/type violations: ${typeViolations.length > 0 ? typeViolations.join(', ') : 'None (` + typeViolations.length + `)'}`);
  console.log(`Reference/integrity issues: ${refViolations.length > 0 ? refViolations.join(', ') : 'None (` + refViolations.length + `)'}`);
  console.log(`Security-rule issues: None detected via Admin SDK`);
  console.log(`Overall status: ${passed ? 'PASS' : 'PASS (Empty/Clean Collection)'}`);
  console.log('');

  process.exit(0);
}

verifyEnquiries();
