import crypto from "crypto";
import { razorpayService } from "../services/razorpay_service";

describe("RazorpayService", () => {
  const TEST_SECRET = "TEST_KEY_SECRET";
  const TEST_WEBHOOK_SECRET = "TEST_WEBHOOK_SECRET";

  beforeAll(() => {
    process.env.RAZORPAY_KEY_SECRET = TEST_SECRET;
    process.env.RAZORPAY_WEBHOOK_SECRET = TEST_WEBHOOK_SECRET;
  });

  test("should verify payment signature correctly", async () => {
    const orderId = "order_test_123";
    const paymentId = "pay_test_123";
    
    // Generate valid signature
    const validSignature = crypto
      .createHmac("sha256", TEST_SECRET)
      .update(orderId + "|" + paymentId)
      .digest("hex");

    const result = await razorpayService.verifyPaymentSignature(orderId, paymentId, validSignature);
    expect(result).toBe(true);

    const invalidResult = await razorpayService.verifyPaymentSignature(orderId, paymentId, "invalid_sig");
    expect(invalidResult).toBe(false);
  });

  test("should verify webhook signature correctly", () => {
    const body = JSON.stringify({ event: "payment.captured", payload: { payment: { entity: { id: "pay_test_123" } } } });
    
    const validSignature = crypto
      .createHmac("sha256", TEST_WEBHOOK_SECRET)
      .update(body)
      .digest("hex");

    const result = razorpayService.verifyWebhookSignature(body, validSignature);
    expect(result).toBe(true);

    const invalidResult = razorpayService.verifyWebhookSignature(body, "invalid_sig");
    expect(invalidResult).toBe(false);
  });
});
