import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.join(__dirname, "../../.env") });

if (!getApps().length) {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;

  if (serviceAccountJson) {
    // Production (Koyeb / Cloud Run): credentials injected as a JSON string env var.
    // The raw JSON is parsed at startup — no private key file on disk required.
    let serviceAccount: object;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT env var is set but is not valid JSON. " +
        "Paste the entire service-account JSON as a single-line string."
      );
    }
    initializeApp({ credential: cert(serviceAccount as any) });
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    // Local development fallback: file-path-based ADC (existing behaviour).
    initializeApp();
  } else {
    throw new Error(
      "Firebase Admin credentials are missing. " +
      "Set FIREBASE_SERVICE_ACCOUNT (JSON string) for production, " +
      "or GOOGLE_APPLICATION_CREDENTIALS (file path) for local development."
    );
  }
}

// The Eventology project uses the 'user-data' named Firestore database,
// not the default database. All agent tools and services must use this instance.
export const db = getFirestore("user-data");
