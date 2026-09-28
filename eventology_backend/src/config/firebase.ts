import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.join(__dirname, "../../.env") });

if (!getApps().length) {
  // Uses GOOGLE_APPLICATION_CREDENTIALS env var (set in .env or shell)
  initializeApp();
}

// The Eventology project uses the 'user-data' named Firestore database,
// not the default database. All agent tools and services must use this instance.
export const db = getFirestore("user-data");
