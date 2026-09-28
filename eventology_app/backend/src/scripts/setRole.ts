import * as admin from 'firebase-admin';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

// Make sure to download your service account key and place it at backend/serviceAccountKey.json
// DO NOT commit serviceAccountKey.json to version control!
const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  console.error('\n❌ ERROR: Could not load serviceAccountKey.json');
  console.error('Please download it from Firebase Console -> Project Settings -> Service Accounts');
  console.error('and save it to backend/serviceAccountKey.json\n');
  process.exit(1);
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log('Usage: npx ts-node src/scripts/setRole.ts <uid> <role>');
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
    await admin.auth().setCustomUserClaims(uid, { role: newRole });
    console.log(`✅ Set custom claim { role: '${newRole}' } for UID: ${uid}`);

    // 2. Update Firestore user-data document to mirror the claim
    const db = admin.firestore();
    // In admin SDK we can target a named database (only available on latest firebase-admin)
    // Actually, getting the named database:
    // admin.firestore() gives default.
    // For a named database: admin.firestore({ databaseId: 'user-data' }) -- this might not be supported in older versions, 
    // Wait, in Firebase Admin SDK Node.js, named databases are supported.
    
    // We will attempt to connect to user-data
    let firestoreDb;
    try {
       // Support for named databases in firebase-admin 11.6+ 
       firestoreDb = admin.firestore(admin.app(), 'user-data');
    } catch(e) {
       console.log('Named database target failed on this firebase-admin version, falling back to default db syntax if it supports it or updating just custom claims.');
       // Fallback
       firestoreDb = admin.firestore();
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
