import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

export interface AIPlanData {
  userId: string;
  eventId: string | null;
  eventRequirements: any;
  recommendations: string[];
  estimatedBudget: string;
  status: string;
}

export async function saveAIPlan(planData: AIPlanData): Promise<string> {
  const plansRef = db.collection("ai_plans");
  const docRef = plansRef.doc();
  
  await docRef.set({
    planId: docRef.id,
    ...planData,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  
  return docRef.id;
}
