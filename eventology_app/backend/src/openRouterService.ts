import { systemInstruction, generatePrompt } from './aiProvider';
import * as dotenv from 'dotenv';
dotenv.config();

export class OpenRouterService {
  async generatePlan(requestData: any): Promise<any> {
    const prompt = generatePrompt(requestData);
    
    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
      },
      body: JSON.stringify({
        model: process.env.OPENROUTER_MODEL || 'meta-llama/llama-3.1-8b-instruct:free',
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemInstruction },
          { role: 'user', content: prompt }
        ]
      })
    });

    if (!response.ok) {
      throw new Error(`OpenRouter API error: ${response.statusText}`);
    }

    const data = await response.json();
    try {
      return JSON.parse(data.choices[0].message.content);
    } catch (e) {
      console.error('Failed to parse OpenRouter JSON output', e);
      throw new Error('Invalid JSON returned by LLM');
    }
  }
}
