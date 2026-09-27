import express from 'express';
import cors from 'cors';
import * as dotenv from 'dotenv';
import { OpenRouterService } from './openRouterService';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const aiService = new OpenRouterService();

app.post('/api/ai/generate-event-plan', async (req, res) => {
  try {
    const requestData = req.body;
    
    // Validate request
    if (!requestData.eventType || !requestData.budget) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const plan = await aiService.generatePlan(requestData);
    res.json(plan);
  } catch (error: any) {
    console.error('Error generating AI plan:', error);
    res.status(500).json({ error: 'Failed to generate plan' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Eventology Backend running on port ${PORT}`);
  console.log(`AI Provider: ${process.env.AI_PROVIDER || 'openrouter'}`);
});
