import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

export async function createAgentTask(workflowId: string, agentType: string, status: string, inputData: any, requiresApproval = false) {
  const ref = db.collection("agent_tasks").doc();
  await ref.set({
    taskId: ref.id,
    eventId: inputData.eventId || null,
    workflowId,
    agentType,
    status,
    input: inputData,
    createdAt: FieldValue.serverTimestamp(),
    requiresApproval,
  });
  return ref.id;
}

export async function updateAgentTaskStatus(taskId: string, status: string, outputData?: any, error?: string) {
  const updates: any = { status };
  if (outputData) updates.output = outputData;
  if (error) updates.error = error;
  
  if (status === "completed" || status === "error" || status === "rejected") {
    updates.completedAt = FieldValue.serverTimestamp();
  }
  
  await db.collection("agent_tasks").doc(taskId).update(updates);
}
