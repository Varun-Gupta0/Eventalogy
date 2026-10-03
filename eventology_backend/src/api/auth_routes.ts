import { Router, Request, Response } from "express";
import { getAuth } from "firebase-admin/auth";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { verifyFirebaseToken } from "../middleware/auth";

const router = Router();

/**
 * POST /api/auth/register-vendor
 *
 * Called during vendor signup. The client has already created a Firebase Auth
 * account (role: 'user' in Firestore). This endpoint:
 *   1. Verifies the Firebase ID token (ensures caller is authenticated)
 *   2. Validates required vendor fields
 *   3. Sets Firebase Custom Claim: { role: 'vendor' }
 *   4. Creates the Firestore vendor document in the vendors collection
 *   5. Updates users/{uid} role field to 'vendor' (informational mirror)
 *   6. Returns vendorId
 *
 * SECURITY:
 *   - Caller must be authenticated (verifyFirebaseToken)
 *   - Role is set by the server — the client CANNOT self-assign 'vendor'
 *   - A user can only register ONE vendor account per UID
 *   - Admin cannot be requested via this endpoint (validated server-side)
 */
router.post("/register-vendor", verifyFirebaseToken, async (req: Request, res: Response) => {
  try {
    const uid = (req as any).user.uid;
    const { businessName, ownerName, phone, categoryIds } = req.body;

    // Validation
    if (!businessName || typeof businessName !== "string" || businessName.trim().length < 2) {
      return res.status(400).json({ error: "businessName is required (min 2 characters)" });
    }
    if (!ownerName || typeof ownerName !== "string" || ownerName.trim().length < 2) {
      return res.status(400).json({ error: "ownerName is required (min 2 characters)" });
    }
    if (!categoryIds || !Array.isArray(categoryIds) || categoryIds.length === 0) {
      return res.status(400).json({ error: "At least one categoryId is required" });
    }

    // Check if vendor already exists for this user
    const existingSnap = await db
      .collection("vendors")
      .where("userId", "==", uid)
      .limit(1)
      .get();

    if (!existingSnap.empty) {
      return res.status(409).json({ error: "A vendor account already exists for this user" });
    }

    // 1. Set Firebase Custom Claim: role = 'vendor'
    await getAuth().setCustomUserClaims(uid, { role: "vendor" });

    // 2. Create vendor document
    const vendorRef = db.collection("vendors").doc();
    const vendorId = vendorRef.id;

    const vendorData = {
      vendorId,
      userId: uid,
      businessName: businessName.trim(),
      ownerName: ownerName.trim(),
      phone: phone?.trim() ?? null,
      categoryIds,
      verified: false,
      status: "pending",
      rating: null,
      description: null,
      pricingModel: null,
      serviceIds: [],
      portfolioImages: [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: null,
    };

    const batch = db.batch();
    batch.set(vendorRef, vendorData);

    // 3. Mirror role in users/{uid} (informational only)
    batch.set(
      db.collection("users").doc(uid),
      { role: "vendor", updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );

    await batch.commit();

    return res.status(201).json({
      success: true,
      vendorId,
      message: "Vendor account created. Please log out and log back in for permissions to take effect.",
    });
  } catch (err: any) {
    console.error("[register-vendor] Error:", err);
    return res.status(500).json({ error: "Failed to register vendor account", detail: err.message });
  }
});

export default router;
