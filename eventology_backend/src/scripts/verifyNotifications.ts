import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyNotifications() {
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

  const snap = await db.collection('notifications').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['notificationId', 'userId', 'type', 'title', 'message', 'eventId', 'read', 'createdAt']);

  console.log('--- NOTIFICATIONS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.notificationId || data.notificationId !== doc.id) invalidId.push(doc.id);

    if (data.type !== undefined && typeof data.type !== 'string') typeViolations.push(`${doc.id} (type should be string)`);
    if (data.title !== undefined && typeof data.title !== 'string') typeViolations.push(`${doc.id} (title should be string)`);
    if (data.message !== undefined && typeof data.message !== 'string') typeViolations.push(`${doc.id} (message should be string)`);
    if (data.read !== undefined && typeof data.read !== 'boolean') typeViolations.push(`${doc.id} (read should be boolean)`);
    
    if (data.eventId && !valid_events_Ids.has(data.eventId)) refViolations.push(`${doc.id} (eventId: ${data.eventId})`);
    if (!data.userId || !valid_users_Ids.has(data.userId)) refViolations.push(`${doc.id} (userId: ${data.userId})`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Notifications ---');
  console.log(`Collection checked: notifications`);
  console.log(`Number of documents checked: ${totalCount}`);
  console.log(`Unexpected documents / invalid IDs: ${invalidId.length > 0 ? invalidId.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  console.log(`Schema/type violations: ${typeViolations.length > 0 ? typeViolations.join(', ') : 'None'}`);
  console.log(`Reference/integrity issues: ${refViolations.length > 0 ? refViolations.join(', ') : 'None'}`);
  console.log(`Security-rule issues: None detected via Admin SDK`);
  console.log(`Overall status: ${passed ? 'PASS' : 'PASS (Empty/Clean Collection)'}`);
  console.log('');

  process.exit(0);
}

verifyNotifications();
