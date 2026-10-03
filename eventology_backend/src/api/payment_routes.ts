import { Router } from "express";
import { razorpayService } from "../services/razorpay_service";
import { verifyFirebaseToken } from "../middleware/auth";
import { db } from "../config/firebase";

export const paymentRoutes = Router();

/**
 * Create a new payment order for a booking.
 */
paymentRoutes.post("/create-order", verifyFirebaseToken, async (req, res) => {
  try {
    const userId = (req as any).user!.uid;
    const { bookingId } = req.body;

    if (!bookingId) {
      return res.status(400).json({ error: "Booking ID is required." });
    }

    // Retrieve booking to get the exact amount
    const bookingDoc = await db.collection("bookings").doc(bookingId).get();
    if (!bookingDoc.exists) {
      return res.status(404).json({ error: "Booking not found." });
    }

    const bookingData = bookingDoc.data()!;
    
    // Validate ownership
    if (bookingData.customerId !== userId) {
      return res.status(403).json({ error: "Unauthorized access to this booking." });
    }

    if (bookingData.paymentStatus === "paid") {
      return res.status(400).json({ error: "Booking is already paid." });
    }

    const amountInPaise = Math.round(bookingData.amount * 100);

    const orderResult = await razorpayService.createOrder(
      userId,
      amountInPaise,
      "Booking Payment",
      { bookingId, eventId: bookingData.eventId }
    );

    res.status(200).json(orderResult);
  } catch (error) {
    console.error("[PaymentRoutes] Create Order Error:", error);
    res.status(500).json({ error: "Failed to create payment order." });
  }
});

/**
 * Verify payment after successful checkout on client side
 */
paymentRoutes.post("/verify", verifyFirebaseToken, async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({ error: "Missing Razorpay verification parameters." });
    }

    const isValid = await razorpayService.verifyPaymentSignature(
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature
    );

    if (!isValid) {
      return res.status(400).json({ error: "Invalid payment signature." });
    }

    await razorpayService.handlePaymentSuccess(
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      "client_verify"
    );

    res.status(200).json({ success: true, message: "Payment verified successfully." });
  } catch (error) {
    console.error("[PaymentRoutes] Verify Payment Error:", error);
    res.status(500).json({ error: "Failed to verify payment." });
  }
});

/**
 * Webhook to receive events from Razorpay
 */
paymentRoutes.post("/webhook", async (req, res) => {
  try {
    const signature = req.headers["x-razorpay-signature"] as string;
    
    // We must pass the raw body string to verify the webhook signature.
    // Ensure that Express doesn't fully parse this if it modifies the string. 
    // Usually using `req.body` stringified or using raw body parser is needed.
    // For simplicity, we assume `req.rawBody` is available or we use `JSON.stringify(req.body)`.
    // In production, configuring raw-body parsing for webhooks is required.
    const bodyString = (req as any).rawBody || JSON.stringify(req.body);

    if (!signature) {
      return res.status(400).json({ error: "Missing signature." });
    }

    const isValid = razorpayService.verifyWebhookSignature(bodyString, signature);

    if (!isValid) {
      return res.status(400).json({ error: "Invalid webhook signature." });
    }

    const event = req.body;

    if (event.event === "payment.captured") {
      const paymentEntity = event.payload.payment.entity;
      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;

      await razorpayService.handlePaymentSuccess(
        orderId,
        paymentId,
        signature,
        "webhook"
      );
    }

    res.status(200).json({ success: true });
  } catch (error) {
    console.error("[PaymentRoutes] Webhook Error:", error);
    res.status(500).json({ error: "Failed to process webhook." });
  }
});

/**
 * Get payment status for a specific booking
 */
paymentRoutes.get("/booking/:bookingId", verifyFirebaseToken, async (req, res) => {
  try {
    const userId = (req as any).user!.uid;
    const { bookingId } = req.params;

    const paymentsSnapshot = await db
      .collection("payments")
      .where("bookingId", "==", bookingId)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (paymentsSnapshot.empty) {
      return res.status(404).json({ error: "No payment found for this booking." });
    }

    const payment = paymentsSnapshot.docs[0].data();

    if (payment.userId !== userId && (req as any).user!.role !== "admin") {
      return res.status(403).json({ error: "Unauthorized access to this payment." });
    }

    res.status(200).json(payment);
  } catch (error) {
    console.error("[PaymentRoutes] Get Payment Error:", error);
    res.status(500).json({ error: "Failed to retrieve payment." });
  }
});
