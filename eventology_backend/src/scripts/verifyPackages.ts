import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
initializeApp({ credential: cert(serviceAccount) });

async function verifyPackages() {
  let db;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const packagesSnap = await db.collection('packages').get();
  
  // Fetch master data for services
  const servicesSnap = await db.collection('services').get();
  const validServiceIds = new Set();
  servicesSnap.forEach(doc => validServiceIds.add(doc.id));

  let totalCount = 0;
  
  const invalidPackageId: string[] = [];
  const duplicateNames: string[] = [];
  const missingName: string[] = [];
  const invalidServiceRefs: string[] = [];
  const missingServiceIds: string[] = [];
  const invalidPrice: string[] = [];
  const invalidDiscount: string[] = [];
  const unexpectedFields: string[] = [];

  const seenNames = new Set<string>();
  
  const expectedFields = new Set([
    'packageId', 'name', 'description', 'serviceIds', 'price', 
    'discount', 'active', 'createdAt', 'updatedAt'
  ]);

  console.log('--- PACKAGE DOCUMENTS ---');
  packagesSnap.forEach(doc => {
    totalCount++;
    const data = doc.data();
    console.log(`Checking package ${doc.id}...`);

    if (!data.packageId || data.packageId !== doc.id) invalidPackageId.push(doc.id);
    if (!data.name || data.name.trim() === '') {
      missingName.push(doc.id);
    } else {
      if (seenNames.has(data.name)) duplicateNames.push(doc.id);
      seenNames.add(data.name);
    }
    
    // Services
    if (!data.serviceIds || !Array.isArray(data.serviceIds) || data.serviceIds.length === 0) {
      missingServiceIds.push(doc.id);
    } else {
      for (const svcId of data.serviceIds) {
        if (!validServiceIds.has(svcId)) {
          invalidServiceRefs.push(`${doc.id} (svc: ${svcId})`);
        }
      }
    }

    // Price
    if (typeof data.price !== 'number' || data.price < 0) {
      invalidPrice.push(doc.id);
    }

    // Discount
    if (data.discount !== undefined && data.discount !== null) {
      if (typeof data.discount !== 'number' || data.discount < 0) {
        invalidDiscount.push(doc.id);
      }
    }

    // Unexpected fields
    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  console.log('--- VERIFICATION REPORT ---');
  console.log(`Total package documents: ${totalCount}`);
  console.log(`Invalid/missing packageId: ${invalidPackageId.length > 0 ? invalidPackageId.join(', ') : 'None'}`);
  console.log(`Missing name: ${missingName.length > 0 ? missingName.join(', ') : 'None'}`);
  console.log(`Duplicate names: ${duplicateNames.length > 0 ? duplicateNames.join(', ') : 'None'}`);
  console.log(`Missing serviceIds: ${missingServiceIds.length > 0 ? missingServiceIds.join(', ') : 'None'}`);
  console.log(`Invalid service references: ${invalidServiceRefs.length > 0 ? invalidServiceRefs.join(', ') : 'None'}`);
  console.log(`Invalid price: ${invalidPrice.length > 0 ? invalidPrice.join(', ') : 'None'}`);
  console.log(`Invalid discount: ${invalidDiscount.length > 0 ? invalidDiscount.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  
  process.exit(0);
}

verifyPackages();
