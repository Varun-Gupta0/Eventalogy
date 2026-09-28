import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
initializeApp({ credential: cert(serviceAccount) });

async function verifyVenues() {
  let db;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const venuesSnap = await db.collection('venues').get();
  
  // Fetch master data to check references
  const locationsSnap = await db.collection('locations').get();
  const validLocationIds = new Set();
  locationsSnap.forEach(doc => validLocationIds.add(doc.id));

  const venueTypesSnap = await db.collection('venueTypes').get();
  const validVenueTypeIds = new Set();
  venueTypesSnap.forEach(doc => validVenueTypeIds.add(doc.id));

  const validStatuses = ['pending', 'active', 'suspended', 'inactive'];

  let totalCount = 0;
  
  const invalidVenueId: string[] = [];
  const missingName: string[] = [];
  const invalidStatus: string[] = [];
  const invalidLocationRefs: string[] = [];
  const invalidVenueTypeRefs: string[] = [];
  const invalidCapacity: string[] = [];
  const unexpectedFields: string[] = [];
  
  const expectedFields = new Set([
    'venueId', 'name', 'description', 'venueTypeId', 'locationId', 
    'capacity', 'priceFrom', 'priceTo', 'amenities', 'images', 
    'contactName', 'contactPhone', 'status', 'verified', 'createdAt', 'updatedAt'
  ]);

  console.log('--- VENUE DOCUMENTS ---');
  venuesSnap.forEach(doc => {
    totalCount++;
    const data = doc.data();
    console.log(`Checking venue ${doc.id}...`);

    if (!data.venueId || data.venueId !== doc.id) invalidVenueId.push(doc.id);
    if (!data.name || data.name.trim() === '') missingName.push(doc.id);
    if (!validStatuses.includes(data.status)) invalidStatus.push(doc.id);
    
    // Capacity
    if (typeof data.capacity !== 'number' || data.capacity < 0) {
      invalidCapacity.push(doc.id);
    }

    // Location ref
    if (!data.locationId || !validLocationIds.has(data.locationId)) {
      invalidLocationRefs.push(doc.id);
    }

    // VenueType ref
    if (!data.venueTypeId || !validVenueTypeIds.has(data.venueTypeId)) {
      invalidVenueTypeRefs.push(doc.id);
    }

    // Unexpected fields
    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  console.log('--- VERIFICATION REPORT ---');
  console.log(`Total venue documents: ${totalCount}`);
  console.log(`Invalid/missing venueId: ${invalidVenueId.length > 0 ? invalidVenueId.join(', ') : 'None'}`);
  console.log(`Missing name: ${missingName.length > 0 ? missingName.join(', ') : 'None'}`);
  console.log(`Invalid status: ${invalidStatus.length > 0 ? invalidStatus.join(', ') : 'None'}`);
  console.log(`Invalid location references: ${invalidLocationRefs.length > 0 ? invalidLocationRefs.join(', ') : 'None'}`);
  console.log(`Invalid venueType references: ${invalidVenueTypeRefs.length > 0 ? invalidVenueTypeRefs.join(', ') : 'None'}`);
  console.log(`Invalid capacity: ${invalidCapacity.length > 0 ? invalidCapacity.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  
  process.exit(0);
}

verifyVenues();
