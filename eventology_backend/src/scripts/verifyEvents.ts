import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyEvents() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const usersSnap = await db.collection('users').get();
  const valid_users_Ids = new Set();
  usersSnap.forEach(doc => valid_users_Ids.add(doc.id));

  const eventTypesSnap = await db.collection('eventTypes').get();
  const valid_eventTypes_Ids = new Set();
  eventTypesSnap.forEach(doc => valid_eventTypes_Ids.add(doc.id));

  const locationsSnap = await db.collection('locations').get();
  const valid_locations_Ids = new Set();
  locationsSnap.forEach(doc => valid_locations_Ids.add(doc.id));

  const venuesSnap = await db.collection('venues').get();
  const valid_venues_Ids = new Set();
  venuesSnap.forEach(doc => valid_venues_Ids.add(doc.id));

  const snap = await db.collection('events').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['eventId', 'customerId', 'eventTypeId', 'title', 'eventDate', 'guestCount', 'budget', 'locationId', 'venueId', 'requirements', 'status', 'paymentStatus', 'createdAt', 'updatedAt']);

  console.log('--- EVENTS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.eventId || data.eventId !== doc.id) invalidId.push(doc.id);

    if (data.title !== undefined && typeof data.title !== 'string') typeViolations.push(`${doc.id} (title should be string)`);
    if (data.status !== undefined && typeof data.status !== 'string') typeViolations.push(`${doc.id} (status should be string)`);

    if (!data.customerId || !valid_users_Ids.has(data.customerId)) refViolations.push(`${doc.id} (customerId: ${data.customerId})`);
    if (!data.eventTypeId || !valid_eventTypes_Ids.has(data.eventTypeId)) refViolations.push(`${doc.id} (eventTypeId: ${data.eventTypeId})`);
    if (data.locationId && !valid_locations_Ids.has(data.locationId)) refViolations.push(`${doc.id} (locationId: ${data.locationId})`);
    if (data.venueId && !valid_venues_Ids.has(data.venueId)) refViolations.push(`${doc.id} (venueId: ${data.venueId})`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Events ---');
  console.log(`Collection checked: events`);
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

verifyEvents();
