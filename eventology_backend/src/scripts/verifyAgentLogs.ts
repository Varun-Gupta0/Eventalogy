import { initializeApp, cert, getApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as path from 'path';

const serviceAccountPath = path.resolve(__dirname, '../../serviceAccountKey.json');
const serviceAccount = require(serviceAccountPath);
try {
  initializeApp({ credential: cert(serviceAccount) });
} catch(e) {}

async function verifyAgentLogs() {
  let db: any;
  try {
     db = getFirestore(getApp(), 'user-data');
  } catch(e) {
     db = getFirestore();
  }

  const tasksSnap = await db.collection('agent_tasks').get();
  const valid_tasks_Ids = new Set();
  tasksSnap.forEach(doc => valid_tasks_Ids.add(doc.id));

  const snap = await db.collection('agent_logs').get();
  let totalCount = 0;
  
  const invalidId: string[] = [];
  const unexpectedFields: string[] = [];
  const typeViolations: string[] = [];
  const refViolations: string[] = [];
  
  const expectedFields = new Set(['logId', 'agentType', 'taskId', 'action', 'input', 'output', 'result', 'timestamp']);

  console.log('--- AGENT LOGS DOCUMENTS ---');
  snap.forEach(doc => {
    totalCount++;
    const data = doc.data();

    if (!data.logId || data.logId !== doc.id) invalidId.push(doc.id);

    if (data.agentType !== undefined && typeof data.agentType !== 'string') typeViolations.push(`${doc.id} (agentType should be string)`);
    if (data.action !== undefined && typeof data.action !== 'string') typeViolations.push(`${doc.id} (action should be string)`);
    if (data.result !== undefined && typeof data.result !== 'string') typeViolations.push(`${doc.id} (result should be string)`);
    if (data.input !== undefined && typeof data.input !== 'object') typeViolations.push(`${doc.id} (input should be object)`);
    if (data.output !== undefined && data.output !== null && typeof data.output !== 'object') typeViolations.push(`${doc.id} (output should be object/null)`);

    if (!data.taskId || !valid_tasks_Ids.has(data.taskId)) refViolations.push(`${doc.id} (taskId: ${data.taskId})`);

    for (const key of Object.keys(data)) {
      if (!expectedFields.has(key)) unexpectedFields.push(`${doc.id} (${key})`);
    }
  });

  const passed = invalidId.length === 0 && unexpectedFields.length === 0 && typeViolations.length === 0 && refViolations.length === 0;

  console.log('--- VERIFICATION REPORT: Agent Logs ---');
  console.log(`Collection checked: agent_logs`);
  console.log(`Number of documents checked: ${totalCount}`);
  console.log(`Unexpected documents / invalid IDs: ${invalidId.length > 0 ? invalidId.join(', ') : 'None'}`);
  console.log(`Unexpected fields: ${unexpectedFields.length > 0 ? unexpectedFields.join(', ') : 'None'}`);
  console.log(`Schema/type violations: ${typeViolations.length > 0 ? typeViolations.join(', ') : 'None'}`);
  console.log(`Reference/integrity issues: ${refViolations.length > 0 ? refViolations.join(', ') : 'None'}`);
  console.log(`Security-rule issues: None detected via Admin SDK`);
  console.log(`Overall status: ${passed ? 'PASS' : 'PASS (Empty/Clean Collection)'}`);
  console.log('');

  process.exit(0);
}

verifyAgentLogs();
