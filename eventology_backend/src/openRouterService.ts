import { systemInstruction, generatePrompt } from './aiProvider';
import * as dotenv from 'dotenv';
dotenv.config();

export class OpenRouterService {
  private apiKey: string;
  private model: string;

  constructor() {
    this.apiKey = process.env.OPENROUTER_API_KEY || '';
    this.model = process.env.OPENROUTER_MODEL || 'meta-llama/llama-3.1-8b-instruct:free';

    if (!this.apiKey || this.apiKey === 'your_openrouter_api_key_here') {
      console.warn('WARNING: OPENROUTER_API_KEY is not set. Please add it to your .env file.');
    }
  }

  async generatePlan(requestData: any): Promise<any> {
    const prompt = generatePrompt(requestData);

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`,
        'HTTP-Referer': 'https://eventology.in',
        'X-Title': 'Eventology AI Planner',
      },
      body: JSON.stringify({
        model: this.model,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemInstruction },
          { role: 'user', content: prompt },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('OpenRouter API error:', errorText);
      throw new Error(`OpenRouter API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json() as any;

    try {
      const content = data.choices[0].message.content;
      return JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse LLM JSON response:', e);
      throw new Error('Invalid JSON returned by LLM');
    }
  }
}
