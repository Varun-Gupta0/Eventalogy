import {
  BaseCheckpointSaver,
  type Checkpoint,
  type CheckpointMetadata,
  type CheckpointTuple,
  type PendingWrite,
  type CheckpointPendingWrite,
} from "@langchain/langgraph-checkpoint";
import type { RunnableConfig } from "@langchain/core/runnables";
import { db } from "../config/firebase";
import { FieldValue } from "firebase-admin/firestore";

const COLLECTION = "_agent_checkpoints";

/**
 * Production Firestore-backed LangGraph checkpoint saver.
 *
 * There is no official Firestore adapter for LangGraph.js — the only
 * production-supported adapters are SQLite and PostgreSQL. Because the
 * Eventology stack is Firestore-first and Cloud SQL is not in scope, a
 * custom implementation extending BaseCheckpointSaver is the correct and
 * necessary approach.
 *
 * NOTE: serde.dumpsTyped and serde.loadsTyped are async (return Promises).
 *
 * Checkpoint layout in Firestore:
 *   _agent_checkpoints/{thread_id}/checkpoints/{checkpoint_id}
 *   _agent_checkpoints/{thread_id}/writes/{task_id}_{idx}
 */
export class FirestoreCheckpointer extends BaseCheckpointSaver {
  async deleteThread(threadId: string): Promise<void> {
    // Delete all checkpoints and writes for a thread
    const threadRef = db.collection(COLLECTION).doc(threadId);
    const [checkSnap, writesSnap] = await Promise.all([
      threadRef.collection("checkpoints").get(),
      threadRef.collection("writes").get(),
    ]);
    const batch = db.batch();
    checkSnap.docs.forEach(d => batch.delete(d.ref));
    writesSnap.docs.forEach(d => batch.delete(d.ref));
    batch.delete(threadRef);
    await batch.commit();
  }

  async put(
    config: RunnableConfig,
    checkpoint: Checkpoint,
    metadata: CheckpointMetadata,
    newVersions: Record<string, number | string>
  ): Promise<RunnableConfig> {
    const threadId = config.configurable?.thread_id as string;
    const checkpointNs = (config.configurable?.checkpoint_ns as string) ?? "";
    const checkpointId = checkpoint.id;

    // dumpsTyped is async — must await
    const [type, data] = await this.serde.dumpsTyped(checkpoint);
    const [mType, mData] = await this.serde.dumpsTyped(metadata);

    const docRef = db
      .collection(COLLECTION)
      .doc(threadId)
      .collection("checkpoints")
      .doc(checkpointId);

    await docRef.set({
      checkpoint_ns: checkpointNs,
      checkpoint_id: checkpointId,
      parent_id: (config.configurable?.checkpoint_id as string) ?? null,
      ts: checkpoint.ts,
      type,
      data: Buffer.from(data),
      metadata_type: mType,
      metadata_data: Buffer.from(mData),
      written_at: FieldValue.serverTimestamp(),
    });

    return {
      configurable: {
        ...config.configurable,
        checkpoint_id: checkpointId,
        checkpoint_ns: checkpointNs,
        thread_id: threadId,
      },
    };
  }

  async putWrites(
    config: RunnableConfig,
    writes: PendingWrite[],
    taskId: string
  ): Promise<void> {
    const threadId = config.configurable?.thread_id as string;
    const checkpointId = config.configurable?.checkpoint_id as string;
    if (!threadId || !checkpointId) return;

    const batch = db.batch();

    await Promise.all(
      writes.map(async ([channel, value], idx) => {
        const [type, data] = await this.serde.dumpsTyped(value);
        const ref = db
          .collection(COLLECTION)
          .doc(threadId)
          .collection("writes")
          .doc(`${taskId}_${idx}`);
        batch.set(ref, {
          checkpoint_id: checkpointId,
          task_id: taskId,
          idx,
          channel,
          type,
          data: Buffer.from(data),
        });
      })
    );

    await batch.commit();
  }

  async getTuple(config: RunnableConfig): Promise<CheckpointTuple | undefined> {
    const threadId = config.configurable?.thread_id as string;
    const checkpointId = config.configurable?.checkpoint_id as string | undefined;
    if (!threadId) return undefined;

    const checkpointsRef = db
      .collection(COLLECTION)
      .doc(threadId)
      .collection("checkpoints");

    let docData: FirebaseFirestore.DocumentData | undefined;
    let docId: string | undefined;

    if (checkpointId) {
      const doc = await checkpointsRef.doc(checkpointId).get();
      if (!doc.exists) return undefined;
      docData = doc.data();
      docId = doc.id;
    } else {
      const snap = await checkpointsRef.orderBy("ts", "desc").limit(1).get();
      if (snap.empty) return undefined;
      docData = snap.docs[0].data();
      docId = snap.docs[0].id;
    }

    if (!docData) return undefined;

    // loadsTyped is async — must await
    const checkpoint = (await this.serde.loadsTyped(
      docData.type,
      Buffer.from(docData.data)
    )) as Checkpoint;
    const metadata = (await this.serde.loadsTyped(
      docData.metadata_type,
      Buffer.from(docData.metadata_data)
    )) as CheckpointMetadata;

    const writesSnap = await db
      .collection(COLLECTION)
      .doc(threadId)
      .collection("writes")
      .where("checkpoint_id", "==", docId)
      .get();

    const pendingWrites: CheckpointPendingWrite[] = await Promise.all(
      writesSnap.docs.map(async (wDoc) => {
        const wd = wDoc.data();
        const value = await this.serde.loadsTyped(wd.type, Buffer.from(wd.data));
        return [wd.task_id, wd.channel, value] as CheckpointPendingWrite;
      })
    );

    const parentConfig = docData.parent_id
      ? {
          configurable: {
            thread_id: threadId,
            checkpoint_ns: docData.checkpoint_ns,
            checkpoint_id: docData.parent_id,
          },
        }
      : undefined;

    return {
      config: {
        configurable: {
          thread_id: threadId,
          checkpoint_ns: docData.checkpoint_ns,
          checkpoint_id: docId,
        },
      },
      checkpoint,
      metadata,
      parentConfig,
      pendingWrites,
    };
  }

  async *list(
    config: RunnableConfig,
    options?: { limit?: number; before?: RunnableConfig }
  ): AsyncGenerator<CheckpointTuple> {
    const threadId = config.configurable?.thread_id as string;
    if (!threadId) return;

    let query: FirebaseFirestore.Query = db
      .collection(COLLECTION)
      .doc(threadId)
      .collection("checkpoints")
      .orderBy("ts", "desc");

    if (options?.limit) query = query.limit(options.limit);

    const snap = await query.get();
    for (const doc of snap.docs) {
      const data = doc.data();
      const checkpoint = (await this.serde.loadsTyped(
        data.type,
        Buffer.from(data.data)
      )) as Checkpoint;
      const metadata = (await this.serde.loadsTyped(
        data.metadata_type,
        Buffer.from(data.metadata_data)
      )) as CheckpointMetadata;

      yield {
        config: {
          configurable: {
            thread_id: threadId,
            checkpoint_ns: data.checkpoint_ns,
            checkpoint_id: doc.id,
          },
        },
        checkpoint,
        metadata,
        parentConfig: data.parent_id
          ? {
              configurable: {
                thread_id: threadId,
                checkpoint_ns: data.checkpoint_ns,
                checkpoint_id: data.parent_id,
              },
            }
          : undefined,
      };
    }
  }
}
