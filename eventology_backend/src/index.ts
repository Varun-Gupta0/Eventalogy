import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { agentRouter } from "./api/agent_routes";
import adminRoutes from "./api/admin_routes";
import whatsappRoutes from "./api/whatsapp_routes";
import authRoutes from "./api/auth_routes";
import { paymentRoutes } from "./api/payment_routes";

dotenv.config();

const app = express();

const corsOptions = {
  origin: process.env.CORS_ORIGIN || "*",
  optionsSuccessStatus: 200,
};
app.use(cors(corsOptions));

// Temporary Request Logging to diagnose Flutter connection
app.use((req, res, next) => {
  console.log(`[INCOMING] ${req.method} ${req.url}`);
  next();
});

// Automatically parse JSON and capture the raw body for WhatsApp HMAC-SHA256 signature validation.
app.use(express.json({
  verify: (req, res, buf) => {
    (req as any).rawBody = buf.toString();
  }
}));

app.use("/api/agent", agentRouter);
app.use("/api/admin", adminRoutes);
app.use("/api/whatsapp", whatsappRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/payments", paymentRoutes);

import { db } from './config/firebase';
import { Timestamp } from 'firebase-admin/firestore';

app.get('/api/seed', async (req, res) => {
  try {
    const locations = [
      { locationId: 'loc_raipur', city: 'Raipur', state: 'Chhattisgarh', country: 'India', active: true, createdAt: Timestamp.now(), timezone: 'Asia/Kolkata' },
      { locationId: 'loc_mumbai', city: 'Mumbai', state: 'Maharashtra', country: 'India', active: true, createdAt: Timestamp.now(), timezone: 'Asia/Kolkata' },
    ];
    for (const loc of locations) await db.collection('locations').doc(loc.locationId).set(loc);

    const venueTypes = [
      { venueTypeId: 'vt_banquet', name: 'Banquet Hall', description: 'Indoor luxury hall', active: true, createdAt: Timestamp.now() },
      { venueTypeId: 'vt_resort', name: 'Luxury Resort', description: 'Outdoor and indoor resort', active: true, createdAt: Timestamp.now() },
    ];
    for (const vt of venueTypes) await db.collection('venueTypes').doc(vt.venueTypeId).set(vt);

    const eventTypes = [
      { eventTypeId: 'et_birthday', name: 'Birthday Party', description: 'A fun celebration', active: true, createdAt: Timestamp.now() },
      { eventTypeId: 'et_wedding', name: 'Wedding', description: 'A grand marriage ceremony', active: true, createdAt: Timestamp.now() },
    ];
    for (const et of eventTypes) await db.collection('eventTypes').doc(et.eventTypeId).set(et);

    const categories = [
      { categoryId: 'cat_catering', name: 'Elite Catering', description: 'Premium food services', active: true, icon: 'restaurant', createdAt: Timestamp.now() },
      { categoryId: 'cat_photography', name: 'Photography', description: 'Capturing memories', active: true, icon: 'camera_alt', createdAt: Timestamp.now() },
    ];
    for (const cat of categories) await db.collection('categories').doc(cat.categoryId).set(cat);

    const venues = [
      {
        venueId: 'v_mayfair_raipur',
        name: 'Mayfair Lake Resort',
        description: 'A 5-star luxury lake resort perfect for grand weddings and premium birthday parties.',
        venueTypeId: 'vt_resort',
        locationId: 'loc_raipur',
        capacity: 1000,
        priceFrom: 100000,
        priceTo: 500000,
        amenities: ['Pool', 'Valet', 'Lake View', 'Catering'],
        images: ['https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&q=80'],
        contactName: 'Resort Manager',
        contactPhone: '+91 9876543210',
        status: 'active',
        verified: true,
        createdAt: Timestamp.now()
      },
      {
        venueId: 'v_courtyard_raipur',
        name: 'Courtyard by Marriott',
        description: 'Elegant indoor banquet hall for sophisticated events.',
        venueTypeId: 'vt_banquet',
        locationId: 'loc_raipur',
        capacity: 500,
        priceFrom: 50000,
        priceTo: 200000,
        amenities: ['AC', 'Wifi', 'In-house Bar'],
        images: ['https://images.unsplash.com/photo-1519741497674-611481863552?w=800&q=80'],
        contactName: 'Banquet Manager',
        contactPhone: '+91 9876543211',
        status: 'active',
        verified: true,
        createdAt: Timestamp.now()
      }
    ];
    for (const ven of venues) await db.collection('venues').doc(ven.venueId).set(ven);

    const vendors = [
      {
        vendorId: 'vend_spices_raipur',
        userId: 'admin_user', // mock
        name: 'Royal Spices Catering',
        businessName: 'Royal Spices',
        description: 'Finest multi-cuisine buffet catering in Raipur.',
        categoryIds: ['cat_catering'],
        locationId: 'loc_raipur',
        images: ['https://images.unsplash.com/photo-1555244162-803834f70033?w=800&q=80'],
        contactEmail: 'catering@royalspices.com',
        contactPhone: '+91 9876543212',
        status: 'active',
        verified: true,
        createdAt: Timestamp.now()
      },
      {
        vendorId: 'vend_lens_raipur',
        userId: 'admin_user', // mock
        name: 'Lenscraft Photography',
        businessName: 'Lenscraft',
        description: 'Cinematic event coverage and drone photography.',
        categoryIds: ['cat_photography'],
        locationId: 'loc_raipur',
        images: ['https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800&q=80'],
        contactEmail: 'hello@lenscraft.com',
        contactPhone: '+91 9876543213',
        status: 'active',
        verified: true,
        createdAt: Timestamp.now()
      }
    ];
    for (const vendor of vendors) await db.collection('vendors').doc(vendor.vendorId).set(vendor);

    res.status(200).json({ success: true, message: 'All Master Data Seeded Successfully!' });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Basic health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "eventology-agent-runtime" });
});

const PORT = parseInt(process.env.PORT as string) || 3000;

const server = app.listen(PORT, "0.0.0.0", () => {
  console.log(`Eventology LangGraph Agent Runtime running on port ${PORT}`);
});
server.setTimeout(600000); // 10 minute timeout
