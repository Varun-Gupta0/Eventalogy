import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { agentRouter } from "./api/agent_routes";
import adminRoutes from "./api/admin_routes";
import whatsappRoutes from "./api/whatsapp_routes";
import authRoutes from "./api/auth_routes";

dotenv.config();

const app = express();
app.use(cors());

// Capture raw body for WhatsApp HMAC-SHA256 signature validation.
// Must be registered BEFORE express.json() parses the body.
app.use((req, res, next) => {
  let data = "";
  req.on("data", (chunk) => { data += chunk; });
  req.on("end", () => {
    (req as any).rawBody = data;
    next();
  });
});

app.use(express.json());

app.use("/api/agent", agentRouter);
app.use("/api/admin", adminRoutes);
app.use("/api/whatsapp", whatsappRoutes);
app.use("/api/auth", authRoutes);

// Basic health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "eventology-agent-runtime" });
});

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`Eventology LangGraph Agent Runtime running on port ${PORT}`);
});
server.setTimeout(600000); // 10 minute timeout
