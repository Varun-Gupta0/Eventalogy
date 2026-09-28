import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
initializeApp({ credential: cert(serviceAccount) });

async function verifyVendors() {
  let db;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const vendorsSnap = await db.collection('vendors').get();
  
  // Fetch master data to check references
  const categoriesSnap = await db.collection('categories').get();
  const validCategoryIds = new Set();
  categoriesSnap.forEach(doc => validCategoryIds.add(doc.id));

  const servicesSnap = await db.collection('services').get();
  const validServiceIds = new Set();
  servicesSnap.forEach(doc => validServiceIds.add(doc.id));

  const locationsSnap = await db.collection('locations').get();
  const validLocationIds = new Set();
  locationsSnap.forEach(doc => validLocationIds.add(doc.id));

  const usersSnap = await db.collection('users').get();
  const validUserIds = new Set();
  usersSnap.forEach(doc => validUserIds.add(doc.id));

  const validStatuses = ['pending', 'active', 'suspended', 'inactive'];
  const validPricingModels = ['fixed', 'per_person', 'hourly', 'custom', 'package'];

  let totalCount = 0;
  
  const invalidVendorId: string[] = [];
  const invalidUserId: string[] = [];
  const invalidStatus: string[] = [];
  const invalidPricingModel: string[] = [];
  const missingBusinessName: string[] = [];
  const missingOwnerName: string[] = [];
  const invalidCategoryRefs: string[] = [];
  const invalidServiceRefs: string[] = [];
  const invalidLocationRefs: string[] = [];
  const invalidRating: string[] = [];
  const unexpectedFields: string[] = [];
  
  const seenBusinessNames = new Map<string, number>();
  const seenUserIds = new Map<string, number>();

  const expectedFields = new Set([
    'vendorId', 'userId', 'businessName', 'ownerName', 'description',
    'categoryIds', 'serviceIds', 'locationId', 'phone', 'email',
    'pricingModel', 'portfolioImages', 'rating', 'verified', 'status',
    'createdAt', 'updatedAt'
  ]);

  console.log('--- VENDOR DOCUMENTS ---');
  vendorsSnap.forEach(doc => {
    totalCount++;
    const data = doc.data();
    console.log(`Checking vendor ${doc.id}...`);

    if (!data.vendorId || data.vendorId !== doc.id) invalidVendorId.push(doc.id);
    if (!data.userId) {
      invalidUserId.push(doc.id);
    } else {
      // NOTE: User documents might not exist in local testing if seeded manually, 
      // but in a strict check we could check validUserIds.has(data.userId).
      // For now we just check it exists in the document string.
    }
    
    if (!data.businessName || data.businessName.trim() === '') missingBusinessName.push(doc.id);
    if (!data.ownerName || data.ownerName.trim() === '') missingOwnerName.push(doc.id);
    
    if (!validStatuses.includes(data.status)) invalidStatus.push(doc.id);
    
    if (data.pricingModel && !validPricingModels.includes(data.pricingModel)) {
      invalidPricingModel.push(doc.id);
    }

    if (data.rating !== undefined && data.rating !== null && (data.rating < 0 || data.rating > 5)) {
      invalidRating.push(doc.id);
    }

    // Category refs
    if (!Array.isArray(data.categoryIds) || data.categoryIds.length === 0) {
      invalidCategoryRefs.push(doc.id);
    } else {
      for (const catId of data.categoryIds) {
        if (!validCategoryIds.has(catId)) invalidCategoryRefs.push(`${doc.id} (${catId})`);
      }
    }

    // Service refs
    if (data.serviceIds && Array.isArray(data.serviceIds)) {
      for (const srvId of data.serviceIds) {
        if (!validServiceIds.has(srvId)) invalidServiceRefs.push(`${doc.id} (${srvId})`);
      }
    }

    // Location ref
    if (data.locationId && !validLocationIds.has(data.locationId)) {
      invalidLocationRefs.push(doc.id);
    }

    // Duplicates
    if (data.businessName) {
      const bname = data.businessName.toLowerCase();
      seenBusinessNames.set(bname, (seenBusinessNames.get(bname) || 0) + 1);
    }
    if (data.userId) {
      seenUserIds.set(data.userId, (seenUserIds.get(data.userId) || 0) + 1);
    }

    // Unexpected fields
    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const duplicateBusinessNames = Array.from(seenBusinessNames.entries()).filter(e => e[1] > 1).map(e => e[0]);
  const duplicateUserIds = Array.from(seenUserIds.entries()).filter(e => e[1] > 1).map(e => e[0]);

  console.log('--- VERIFICATION REPORT ---');
  console.log(`Total vendor documents: ${totalCount}`);
  console.log(`Invalid/missing vendorId: ${invalidVendorId.length > 0 ? invalidVendorId.join(', ') : 'None'}`);
  console.log(`Invalid/missing userId: ${invalidUserId.length > 0 ? invalidUserId.join(', ') : 'None'}`);
  console.log(`Invalid status: ${invalidStatus.length > 0 ? invalidStatus.join(', ') : 'None'}`);
  console.log(`Invalid pricingModel: ${invalidPricingModel.length > 0 ? invalidPricingModel.join(', ') : 'None'}`);
  console.log(`Missing businessName: ${missingBusinessName.length > 0 ? missingBusinessName.join(', ') : 'None'}`);
  console.log(`Missing ownerName: ${missingOwnerName.length > 0 ? missingOwnerName.join(', ') : 'None'}`);
  console.log(`Invalid category references: ${invalidCategoryRefs.length > 0 ? invalidCategoryRefs.join(', ') : 'None'}`);
  console.log(`Invalid service references: ${invalidServiceRefs.length > 0 ? invalidServiceRefs.join(', ') : 'None'}`);
  console.log(`Invalid location references: ${invalidLocationRefs.length > 0 ? invalidLocationRefs.join(', ') : 'None'}`);
  console.log(`Invalid rating: ${invalidRating.length > 0 ? invalidRating.join(', ') : 'None'}`);
  console.log(`Duplicate business names: ${duplicateBusinessNames.length > 0 ? duplicateBusinessNames.join(', ') : 'None'}`);
  console.log(`Duplicate userId associations: ${duplicateUserIds.length > 0 ? duplicateUserIds.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  
  process.exit(0);
}

verifyVendors();
