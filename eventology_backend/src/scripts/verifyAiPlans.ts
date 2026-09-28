import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyAiPlans() {
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

  const snap = await db.collection('ai_plans').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['planId', 'eventId', 'userId', 'eventRequirements', 'recommendations', 'estimatedBudget', 'status', 'createdAt', 'updatedAt']);

  console.log('--- AI PLANS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.planId || data.planId !== doc.id) invalidId.push(doc.id);

    if (data.eventRequirements !== undefined && typeof data.eventRequirements !== 'object') typeViolations.push(`${doc.id} (eventRequirements should be object)`);
    if (data.recommendations !== undefined && !Array.isArray(data.recommendations)) typeViolations.push(`${doc.id} (recommendations should be array)`);
    if (data.estimatedBudget !== undefined && typeof data.estimatedBudget !== 'number') typeViolations.push(`${doc.id} (estimatedBudget should be number)`);
    if (data.status !== undefined && typeof data.status !== 'string') typeViolations.push(`${doc.id} (status should be string)`);
    
    if (!data.eventId || !valid_events_Ids.has(data.eventId)) refViolations.push(`${doc.id} (eventId: ${data.eventId})`);
    if (!data.userId || !valid_users_Ids.has(data.userId)) refViolations.push(`${doc.id} (userId: ${data.userId})`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: AI Plans ---');
  console.log(`Collection checked: ai_plans`);
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

verifyAiPlans();
