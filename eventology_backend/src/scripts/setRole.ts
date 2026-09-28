import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');

try {
  const serviceAccount = require(serviceAccountPath);
  initializeApp({
    credential: cert(serviceAccount)
  });
} catch (error) {
  console.error('\n❌ ERROR: Could not load serviceAccountKey.json');
  console.error('Ensure serviceAccountKey.json is in the eventology_backend/ root directory.\n');
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log('Usage: npm run set-role <uid> <role>');
  console.log('Roles: user, vendor, admin');
  process.exit(1);
}

const uid = args[0];
const newRole = args[1];

if (!['user', 'vendor', 'admin'].includes(newRole)) {
  console.error('Invalid role. Must be: user, vendor, admin');
  process.exit(1);
}

async function setRole() {
  try {
    // 1. Set Custom Claim
    await getAuth().setCustomUserClaims(uid, { role: newRole });
    console.log(`✅ Set custom claim { role: '${newRole}' } for UID: ${uid}`);

    // 2. Update Firestore user-data document to mirror the claim
    let firestoreDb;
    try {
       // Try connecting specifically to the user-data named database
       firestoreDb = getFirestore(getApp(), 'user-data');
    } catch(e) {
       console.log('Named database target failed on this firebase-admin version, falling back to default db syntax.');
       firestoreDb = getFirestore();
    }

    await firestoreDb.collection('users').doc(uid).set({ role: newRole }, { merge: true });
    console.log(`✅ Updated Firestore users/${uid} with role: '${newRole}' in user-data database`);

    console.log('\nSUCCESS! The user must log out and log back in (or wait for token refresh) to receive the new permissions.');
  } catch (error) {
    console.error('Error setting role:', error);
  } finally {
    process.exit(0);
  }
}

setRole();
