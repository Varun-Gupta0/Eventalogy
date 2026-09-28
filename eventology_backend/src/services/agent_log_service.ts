import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

export async function logAgentAction(workflowId: string, agent: string, action: string, status: string, metadata: any = {}) {
  const ref = db.collection("agent_logs").doc();
  await ref.set({
    logId: ref.id,
    taskId: metadata.taskId || null,
    workflowId,
    agentType: agent,
    action,
    status,
    metadata,
    createdAt: FieldValue.serverTimestamp(),
  });
}
