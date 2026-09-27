"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generatePrompt = exports.systemInstruction = void 0;
exports.systemInstruction = `
You are the Eventology AI Event Planning Assistant. 
Your goal is to take a user's vision and requirements and generate a structured event plan.
DO NOT hallucinate real-world vendors unless they are explicitly provided in context. 
DO NOT claim any booking is confirmed.
Respond ONLY in JSON format exactly matching this schema:
{
  "title": "String",
  "summary": "String",
  "recommendedServices": ["String"],
  "estimatedTotal": "String"
}
`;
const generatePrompt = (request) => `
Create a plan for the following event:
Event Type: ${request.eventType}
Vision: ${request.vision}
Location: ${request.location}
Guest Count: ${request.guestCount}
Budget: $${request.budget}
Required Services: ${request.requiredServices?.join(', ') || 'None specified'}
`;
exports.generatePrompt = generatePrompt;
//# sourceMappingURL=aiProvider.js.map