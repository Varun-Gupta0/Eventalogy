import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
initializeApp({ credential: cert(serviceAccount) });

async function verify() {
  let db;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const categoriesSnap = await db.collection('categories').get();
  const categoryMap = new Map();
  const legacyNames = ["Dream Venues", "Live Bands & DJs", "Elite Decor & Floral", "Master Photographers", "Catering & Mixology"];
  const standardNames = ["Photography", "Catering", "Decoration", "Entertainment", "Beauty", "Transportation", "Invitation"];

  categoriesSnap.forEach(doc => {
    categoryMap.set(doc.id, doc.data().name || '');
  });

  const servicesSnap = await db.collection('services').get();
  const expectedServices = [
    "Event Photography", "Videography", "Full-Service Catering", "Buffet Catering",
    "Event Decoration", "Floral Decoration", "DJ Services", "Live Band",
    "Event Makeup", "Hairstyling", "Guest Transportation", "Luxury Car Rental",
    "Digital Invitations", "Printed Invitations"
  ];

  let totalCount = 0;
  const foundServices: string[] = [];
  const missingServices: string[] = [];
  const duplicateNames: string[] = [];
  const invalidCategoryRefs: string[] = [];
  const legacyCategoryRefs: string[] = [];
  const unexpectedPrices: string[] = [];
  const unexpectedImages: string[] = [];

  console.log('--- SERVICE DOCUMENTS ---');
  servicesSnap.forEach(doc => {
    totalCount++;
    const data = doc.data();
    const catName = categoryMap.get(data.categoryId) || 'UNKNOWN';
    
    console.log(`ID: ${doc.id}`);
    console.log(`  Name: ${data.name}`);
    console.log(`  CategoryID: ${data.categoryId} (${catName})`);
    console.log(`  Active: ${data.active}`);
    console.log(`  PricingModel: ${data.pricingModel}`);
    console.log(`  BasePrice is null/undefined: ${data.basePrice == null}`);
    console.log(`  Images is empty: ${Array.isArray(data.images) && data.images.length === 0}`);
    console.log('');

    if (foundServices.includes(data.name)) {
      duplicateNames.push(data.name);
    } else {
      foundServices.push(data.name);
    }

    if (!categoryMap.has(data.categoryId) || !standardNames.includes(catName)) {
      if (legacyNames.includes(catName)) {
        legacyCategoryRefs.push(data.name);
      } else {
        invalidCategoryRefs.push(data.name);
      }
    }

    if (data.basePrice != null) {
      unexpectedPrices.push(data.name);
    }

    if (!Array.isArray(data.images) || data.images.length > 0) {
      unexpectedImages.push(data.name);
    }
  });

  expectedServices.forEach(expected => {
    if (!foundServices.includes(expected)) {
      missingServices.push(expected);
    }
  });

  console.log('--- VERIFICATION REPORT ---');
  console.log(`Total service count: ${totalCount}`);
  console.log(`Missing services: ${missingServices.length > 0 ? missingServices.join(', ') : 'None'}`);
  console.log(`Duplicate service names: ${duplicateNames.length > 0 ? duplicateNames.join(', ') : 'None'}`);
  console.log(`Invalid category references: ${invalidCategoryRefs.length > 0 ? invalidCategoryRefs.join(', ') : 'None'}`);
  console.log(`Legacy category references: ${legacyCategoryRefs.length > 0 ? legacyCategoryRefs.join(', ') : 'None'}`);
  console.log(`Services with unexpected prices: ${unexpectedPrices.length > 0 ? unexpectedPrices.join(', ') : 'None'}`);
  console.log(`Services with unexpected images: ${unexpectedImages.length > 0 ? unexpectedImages.join(', ') : 'None'}`);
  
  const passed = missingServices.length === 0 && duplicateNames.length === 0 && 
                 invalidCategoryRefs.length === 0 && legacyCategoryRefs.length === 0 && 
                 unexpectedPrices.length === 0 && unexpectedImages.length === 0 &&
                 totalCount === 14;

  console.log(`\nOVERALL RESULT: ${passed ? 'PASS' : 'FAIL'}`);
  process.exit(0);
}

verify();
