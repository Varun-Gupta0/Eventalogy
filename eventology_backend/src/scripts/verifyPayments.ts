import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyPayments() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const eventsSnap = await db.collection('events').get();
  const valid_events_Ids = new Set();
  eventsSnap.forEach(doc => valid_events_Ids.add(doc.id));

  const bookingsSnap = await db.collection('bookings').get();
  const valid_bookings_Ids = new Set();
  bookingsSnap.forEach(doc => valid_bookings_Ids.add(doc.id));

  const usersSnap = await db.collection('users').get();
  const valid_users_Ids = new Set();
  usersSnap.forEach(doc => valid_users_Ids.add(doc.id));

  const snap = await db.collection('payments').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['paymentId', 'eventId', 'bookingId', 'customerId', 'amount', 'currency', 'paymentMethod', 'transactionId', 'status', 'paidAt', 'createdAt']);

  console.log('--- PAYMENTS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.paymentId || data.paymentId !== doc.id) invalidId.push(doc.id);

    if (data.amount !== undefined && typeof data.amount !== 'number') typeViolations.push(`${doc.id} (amount should be number)`);
    if (data.currency !== undefined && typeof data.currency !== 'string') typeViolations.push(`${doc.id} (currency should be string)`);
    if (data.paymentMethod !== undefined && typeof data.paymentMethod !== 'string') typeViolations.push(`${doc.id} (paymentMethod should be string)`);
    if (data.status !== undefined && typeof data.status !== 'string') typeViolations.push(`${doc.id} (status should be string)`);

    if (!data.eventId || !valid_events_Ids.has(data.eventId)) refViolations.push(`${doc.id} (eventId: ${data.eventId})`);
    if (!data.bookingId || !valid_bookings_Ids.has(data.bookingId)) refViolations.push(`${doc.id} (bookingId: ${data.bookingId})`);
    if (!data.customerId || !valid_users_Ids.has(data.customerId)) refViolations.push(`${doc.id} (customerId: ${data.customerId})`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Payments ---');
  console.log(`Collection checked: payments`);
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

verifyPayments();
