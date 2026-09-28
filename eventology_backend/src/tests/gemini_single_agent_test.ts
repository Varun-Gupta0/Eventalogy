import * as dotenv from "dotenv";
import * as path from "path";
import * as http from "http";

dotenv.config({ path: path.join(__dirname, "../../.env"), override: true });

async function runSingleAgentTest() {
  console.log("==========================================");
  console.log("   SINGLE-AGENT REAL TEST (GEMINI)");
  console.log("==========================================");

  // 1. Authenticate with Firebase REST API to get a real ID token
  console.log("\n[1] Authenticating test user...");
  const authResponse = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${process.env.FIREBASE_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: process.env.TEST_USER_EMAIL,
      password: process.env.TEST_USER_PASSWORD,
      returnSecureToken: true
    })
  });
  
  const authData: any = await authResponse.json();
  if (!authData.idToken) {
    console.error("❌ Firebase Auth Failed:", authData);
    process.exit(1);
  }
  const token = authData.idToken;
  console.log(`✅ Authenticated as ${authData.email} (UID: ${authData.localId})`);

  // 2. Send Chat Request
  console.log("\n[2] Sending Chat Request to /api/agent/chat...");
  const prompt = "I want to organize a birthday event in Raipur for 100 people.";
  console.log(`    Prompt: "${prompt}"`);

  const reqBody = JSON.stringify({ message: prompt });
  
  const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/api/agent/chat',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
      'Content-Length': Buffer.byteLength(reqBody)
    }
  };

  const req = http.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log(`\n[3] Response Received (Status: ${res.statusCode})`);
      try {
        const json = JSON.parse(data);
        console.log(JSON.stringify(json, null, 2));
        
        if (json.state && json.state.currentStage) {
          console.log(`✅ Workflow successfully progressed to: ${json.state.currentStage}`);
          if (json.state.lastError) {
             console.log(`⚠️ Note: Error encountered: ${json.state.lastError}`);
          }
        }
      } catch(e) {
        console.error("❌ Failed to parse response:", data);
      }
      process.exit(0);
    });
  });

  req.on('error', (e) => {
    console.error(`❌ Request error: ${e.message}`);
    process.exit(1);
  });
  
  // Set a large timeout for the LLM
  req.setTimeout(120000, () => {
    console.error('❌ Request timed out after 120s');
    req.destroy();
    process.exit(1);
  });

  req.write(reqBody);
  req.end();
}

runSingleAgentTest();
