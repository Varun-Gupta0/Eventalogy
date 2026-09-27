import express, { Request, Response } from 'express';
import cors from 'cors';
import * as dotenv from 'dotenv';
import { OpenRouterService } from './openRouterService';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const aiService = new OpenRouterService();

// Health check
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'Eventology AI Backend' });
});

// Generate Event Plan
app.post('/api/ai/generate-event-plan', async (req: Request, res: Response) => {
  try {
    const requestData = req.body;

    // Validate required fields
    if (!requestData.eventType || !requestData.budget) {
      return res.status(400).json({ error: 'Missing required fields: eventType and budget are required.' });
    }

    console.log(`Generating plan for: ${requestData.eventType} with budget ₹${requestData.budget}`);

    const plan = await aiService.generatePlan(requestData);
    return res.json(plan);

  } catch (error: any) {
    console.error('Error generating AI plan:', error.message);
    return res.status(500).json({ error: 'Failed to generate plan. Please try again.' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n✅ Eventology Backend is running on http://localhost:${PORT}`);
  console.log(`🤖 AI Model: ${process.env.OPENROUTER_MODEL || 'meta-llama/llama-3.1-8b-instruct:free'}`);
  console.log(`📡 Endpoint: POST http://localhost:${PORT}/api/ai/generate-event-plan\n`);
});
