import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { agentRouter } from "./api/agent_routes";
import adminRoutes from "./api/admin_routes";
import whatsappRoutes from "./api/whatsapp_routes";
import authRoutes from "./api/auth_routes";
import { paymentRoutes } from "./api/payment_routes";

dotenv.config();

const app = express();

const corsOptions = {
  origin: process.env.CORS_ORIGIN || "*",
  optionsSuccessStatus: 200,
};
app.use(cors(corsOptions));

// Temporary Request Logging to diagnose Flutter connection
app.use((req, res, next) => {
  console.log(`[INCOMING] ${req.method} ${req.url}`);
  next();
});

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
app.use("/api/payments", paymentRoutes);

// Basic health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "eventology-agent-runtime" });
});

const PORT = parseInt(process.env.PORT as string) || 3000;

const server = app.listen(PORT, "0.0.0.0", () => {
  console.log(`Eventology LangGraph Agent Runtime running on port ${PORT}`);
});
server.setTimeout(600000); // 10 minute timeout
