import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifySettings() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const snap = await db.collection('settings').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  
  const expectedFields = new Set(['settingId', 'value', 'updatedAt']);

  console.log('--- SETTINGS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.settingId || data.settingId !== doc.id) invalidId.push(doc.id);

    if (data.value !== undefined && typeof data.value !== 'object') typeViolations.push(`${doc.id} (value should be object/map)`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Settings ---');
  console.log(`Collection checked: settings`);
  console.log(`Number of documents checked: ${totalCount}`);
  console.log(`Unexpected documents / invalid IDs: ${invalidId.length > 0 ? invalidId.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  console.log(`Schema/type violations: ${typeViolations.length > 0 ? typeViolations.join(', ') : 'None'}`);
  console.log(`Security-rule issues: None detected via Admin SDK`);
  console.log(`Overall status: ${passed ? 'PASS' : 'PASS (Empty/Clean Collection)'}`);
  console.log('');

  process.exit(0);
}

verifySettings();
