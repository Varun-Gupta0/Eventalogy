import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { agentRouter } from "./api/agent_routes";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use("/api/agent", agentRouter);

// Basic health check
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "eventology-agent-runtime" });
});

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`Eventology LangGraph Agent Runtime running on port ${PORT}`);
});
server.setTimeout(600000); // 10 minute timeout
