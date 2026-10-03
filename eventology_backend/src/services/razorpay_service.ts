import Razorpay from "razorpay";
import crypto from "crypto";
import { db } from "../config/firebase";

export interface PaymentModel {
  paymentId: string;
  userId: string;
  eventId?: string;
  bookingId?: string;
  allocationId?: string;
  amount: number;
  currency: string;
  razorpayOrderId?: string;
  razorpayPaymentId?: string;
  razorpaySignature?: string;
  status: "created" | "pending" | "paid" | "failed" | "refunded";
  purpose: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  paidAt?: FirebaseFirestore.Timestamp;
  failureReason?: string;
  metadata?: Record<string, any>;
}

export class RazorpayService {
  private razorpay: any;
  private webhookSecret: string;

  constructor() {
    this.razorpay = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID || "TEST_KEY_ID",
      key_secret: process.env.RAZORPAY_KEY_SECRET || "TEST_KEY_SECRET",
    });
    this.webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || "TEST_WEBHOOK_SECRET";
  }

  /**
   * Create a Razorpay Order and store the initial payment record in Firestore
   */
  async createOrder(
    userId: string,
    amountInPaise: number,
    purpose: string,
    metadata: { eventId?: string; bookingId?: string; allocationId?: string }
  ): Promise<{ orderId: string; paymentId: string; amount: number; currency: string }> {
    // 1. Create order in Razorpay
    const options = {
      amount: amountInPaise,
      currency: "INR",
      receipt: `rcpt_${userId}_${Date.now()}`.substring(0, 40),
    };

    const order = await this.razorpay.orders.create(options);

    // 2. Create Payment record in Firestore
    const paymentRef = db.collection("payments").doc();
    const paymentData: PaymentModel = {
      paymentId: paymentRef.id,
      userId,
      eventId: metadata.eventId,
      bookingId: metadata.bookingId,
      allocationId: metadata.allocationId,
      amount: amountInPaise / 100, // store in INR
      currency: "INR",
      razorpayOrderId: order.id,
      status: "pending",
      purpose,
      createdAt: FirebaseFirestore.Timestamp.now(),
      updatedAt: FirebaseFirestore.Timestamp.now(),
      metadata,
    };

    await paymentRef.set(paymentData);

    return {
      orderId: order.id,
      paymentId: paymentRef.id,
      amount: amountInPaise,
      currency: "INR",
    };
  }

  /**
   * Verify signature after checkout completes successfully on client side
   */
  async verifyPaymentSignature(
    razorpayOrderId: string,
    razorpayPaymentId: string,
    razorpaySignature: string
  ): Promise<boolean> {
    const secret = process.env.RAZORPAY_KEY_SECRET || "TEST_KEY_SECRET";
    const body = razorpayOrderId + "|" + razorpayPaymentId;
    const expectedSignature = crypto
      .createHmac("sha256", secret)
      .update(body.toString())
      .digest("hex");

    return expectedSignature === razorpaySignature;
  }

  /**
   * Process a payment success event (can be from verify API or webhook)
   */
  async handlePaymentSuccess(
    razorpayOrderId: string,
    razorpayPaymentId: string,
    razorpaySignature: string,
    source: "client_verify" | "webhook"
  ): Promise<void> {
    // Find the payment by order ID
    const paymentsSnapshot = await db
      .collection("payments")
      .where("razorpayOrderId", "==", razorpayOrderId)
      .limit(1)
      .get();

    if (paymentsSnapshot.empty) {
      console.warn(`[RazorpayService] No payment found for order: ${razorpayOrderId}`);
      return;
    }

    const paymentDoc = paymentsSnapshot.docs[0];
    const payment = paymentDoc.data() as PaymentModel;

    if (payment.status === "paid") {
      console.log(`[RazorpayService] Payment ${payment.paymentId} already marked as paid. Idempotent return.`);
      return;
    }

    // Update payment record
    await paymentDoc.ref.update({
      status: "paid",
      razorpayPaymentId,
      razorpaySignature,
      updatedAt: FirebaseFirestore.Timestamp.now(),
      paidAt: FirebaseFirestore.Timestamp.now(),
      "metadata.source": source,
    });

    // Update Booking status if applicable
    if (payment.bookingId) {
      const bookingRef = db.collection("bookings").doc(payment.bookingId);
      const bookingDoc = await bookingRef.get();
      if (bookingDoc.exists) {
        await bookingRef.update({
          paymentStatus: "paid",
          updatedAt: FirebaseFirestore.Timestamp.now(),
        });
      }
    }
  }

  /**
   * Verify webhook signature sent by Razorpay
   */
  verifyWebhookSignature(body: string, signature: string): boolean {
    const expectedSignature = crypto
      .createHmac("sha256", this.webhookSecret)
      .update(body)
      .digest("hex");
    return expectedSignature === signature;
  }
}

export const razorpayService = new RazorpayService();
