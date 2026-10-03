import { Router, Request, Response } from "express";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

const router = Router();

// Middleware to ensure user is admin
const requireAdmin = async (req: Request, res: Response, next: Function) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Missing or invalid authorization" });
    }
    const token = authHeader.split("Bearer ")[1];
    const { getAuth } = require("firebase-admin/auth");
    const decodedToken = await getAuth().verifyIdToken(token);
    
    if (decodedToken.role !== "admin") {
      return res.status(403).json({ error: "Admin access required" });
    }
    
    // Inject user info
    (req as any).user = decodedToken;
    next();
  } catch (err: any) {
    return res.status(401).json({ error: "Unauthorized", details: err.message });
  }
};

router.use(requireAdmin);

// ── Vendor Operations ─────────────────────────────────────────────────────────

router.post("/vendors/:id/verify", async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const adminUid = (req as any).user.uid;
    
    const vendorRef = db.collection("vendors").doc(id);
    const vendorDoc = await vendorRef.get();
    
    if (!vendorDoc.exists) {
      return res.status(404).json({ error: "Vendor not found" });
    }
    
    if (vendorDoc.data()?.verified === true) {
      return res.status(400).json({ error: "Vendor is already verified" });
    }
    
    const batch = db.batch();
    batch.update(vendorRef, { verified: true, updatedAt: FieldValue.serverTimestamp() });
    
    const auditRef = db.collection("audit_logs").doc();
    batch.set(auditRef, {
      action: "verify_vendor",
      targetId: id,
      targetType: "vendor",
      adminId: adminUid,
      timestamp: FieldValue.serverTimestamp(),
      details: { previousState: false, newState: true }
    });
    
    await batch.commit();
    return res.json({ success: true });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

router.post("/vendors/:id/status", async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const { status } = req.body; // 'active', 'suspended', etc.
    const adminUid = (req as any).user.uid;
    
    const validStatuses = ["active", "suspended", "inactive", "pending"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: "Invalid status" });
    }
    
    const vendorRef = db.collection("vendors").doc(id);
    const vendorDoc = await vendorRef.get();
    
    if (!vendorDoc.exists) {
      return res.status(404).json({ error: "Vendor not found" });
    }
    
    const oldStatus = vendorDoc.data()?.status;
    if (oldStatus === status) {
      return res.status(400).json({ error: `Vendor is already ${status}` });
    }
    
    const batch = db.batch();
    batch.update(vendorRef, { status, updatedAt: FieldValue.serverTimestamp() });
    
    const auditRef = db.collection("audit_logs").doc();
    batch.set(auditRef, {
      action: "change_vendor_status",
      targetId: id,
      targetType: "vendor",
      adminId: adminUid,
      timestamp: FieldValue.serverTimestamp(),
      details: { previousState: oldStatus, newState: status }
    });
    
    await batch.commit();
    return res.json({ success: true });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Event Operations ──────────────────────────────────────────────────────────

router.post("/events/:id/cancel", async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const adminUid = (req as any).user.uid;
    
    const eventRef = db.collection("events").doc(id);
    const eventDoc = await eventRef.get();
    
    if (!eventDoc.exists) {
      return res.status(404).json({ error: "Event not found" });
    }
    
    const oldStatus = eventDoc.data()?.status;
    if (oldStatus === "cancelled") {
      return res.status(400).json({ error: "Event is already cancelled" });
    }
    
    const batch = db.batch();
    batch.update(eventRef, { status: "cancelled", updatedAt: FieldValue.serverTimestamp() });
    
    // Cascading cancellations
    const bookingsSnap = await db.collection("bookings").where("eventId", "==", id).get();
    bookingsSnap.docs.forEach(doc => {
      if (doc.data().status !== "cancelled") {
        batch.update(doc.ref, { status: "cancelled", updatedAt: FieldValue.serverTimestamp() });
      }
    });
    
    const enquiriesSnap = await db.collection("enquiries").where("eventId", "==", id).get();
    enquiriesSnap.docs.forEach(doc => {
      if (doc.data().status !== "cancelled" && doc.data().status !== "declined") {
        batch.update(doc.ref, { status: "cancelled", updatedAt: FieldValue.serverTimestamp() });
      }
    });
    
    const auditRef = db.collection("audit_logs").doc();
    batch.set(auditRef, {
      action: "cancel_event",
      targetId: id,
      targetType: "event",
      adminId: adminUid,
      timestamp: FieldValue.serverTimestamp(),
      details: { previousState: oldStatus, newState: "cancelled", cascaded: true }
    });
    
    await batch.commit();
    return res.json({ success: true });
  } catch (err: any) {
    return res.status(500).json({ error: err.message });
  }
});

export default router;
