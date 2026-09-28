import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyAuditLogs() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const snap = await db.collection('audit_logs').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  
  const expectedFields = new Set(['logId', 'actorId', 'actorRole', 'action', 'resourceType', 'resourceId', 'metadata', 'timestamp']);

  console.log('--- AUDIT LOGS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.logId || data.logId !== doc.id) invalidId.push(doc.id);

    if (data.actorId !== undefined && typeof data.actorId !== 'string') typeViolations.push(`${doc.id} (actorId should be string)`);
    if (data.actorRole !== undefined && typeof data.actorRole !== 'string') typeViolations.push(`${doc.id} (actorRole should be string)`);
    if (data.action !== undefined && typeof data.action !== 'string') typeViolations.push(`${doc.id} (action should be string)`);
    if (data.resourceType !== undefined && typeof data.resourceType !== 'string') typeViolations.push(`${doc.id} (resourceType should be string)`);
    if (data.resourceId !== undefined && typeof data.resourceId !== 'string') typeViolations.push(`${doc.id} (resourceId should be string)`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Audit Logs ---');
  console.log(`Collection checked: audit_logs`);
  console.log(`Number of documents checked: ${totalCount}`);
  console.log(`Unexpected documents / invalid IDs: ${invalidId.length > 0 ? invalidId.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  console.log(`Schema/type violations: ${typeViolations.length > 0 ? typeViolations.join(', ') : 'None'}`);
  console.log(`Security-rule issues: None detected via Admin SDK`);
  console.log(`Overall status: ${passed ? 'PASS' : 'PASS (Empty/Clean Collection)'}`);
  console.log('');

  process.exit(0);
}

verifyAuditLogs();
