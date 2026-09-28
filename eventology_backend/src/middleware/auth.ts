import * as express from "express";
import { getAuth } from "firebase-admin/auth";

/**
 * Middleware that verifies a Firebase ID token from the Authorization header.
 * Attaches the decoded token (including uid) to req.user.
 *
 * Usage: agentRouter.post("/chat", verifyFirebaseToken, handler)
 */
export async function verifyFirebaseToken(
  req: express.Request,
  res: express.Response,
  next: express.NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing or invalid Authorization header. Expected: Bearer <idToken>" });
    return;
  }

  const idToken = authHeader.split("Bearer ")[1];
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    (req as any).user = decoded;
    next();
  } catch (err: any) {
    res.status(401).json({ error: "Invalid or expired Firebase ID token.", detail: err.message });
  }
}
