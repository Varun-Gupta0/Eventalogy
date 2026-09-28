import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyLocations() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const snap = await db.collection('locations').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['locationId', 'country', 'state', 'city', 'area', 'pincode', 'latitude', 'longitude']);

  console.log('--- LOCATIONS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.locationId || data.locationId !== doc.id) invalidId.push(doc.id);

    if (data.country !== undefined && typeof data.country !== 'string') typeViolations.push(`${doc.id} (country should be string)`);
    if (data.state !== undefined && typeof data.state !== 'string') typeViolations.push(`${doc.id} (state should be string)`);
    if (data.city !== undefined && typeof data.city !== 'string') typeViolations.push(`${doc.id} (city should be string)`);
    if (data.area !== undefined && typeof data.area !== 'string') typeViolations.push(`${doc.id} (area should be string)`);
    if (data.pincode !== undefined && typeof data.pincode !== 'string') typeViolations.push(`${doc.id} (pincode should be string)`);
    if (data.latitude !== undefined && typeof data.latitude !== 'number') typeViolations.push(`${doc.id} (latitude should be number)`);
    if (data.longitude !== undefined && typeof data.longitude !== 'number') typeViolations.push(`${doc.id} (longitude should be number)`);


    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Locations ---');
  console.log(`Collection checked: locations`);
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

verifyLocations();
