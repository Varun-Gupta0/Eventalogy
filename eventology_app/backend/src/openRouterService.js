"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpenRouterService = void 0;
const aiProvider_1 = require("./aiProvider");
const dotenv = __importStar(require("dotenv"));
dotenv.config();
class OpenRouterService {
    async generatePlan(requestData) {
        const prompt = (0, aiProvider_1.generatePrompt)(requestData);
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
                    { role: 'system', content: aiProvider_1.systemInstruction },
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
        }
        catch (e) {
            console.error('Failed to parse OpenRouter JSON output', e);
            throw new Error('Invalid JSON returned by LLM');
        }
    }
}
exports.OpenRouterService = OpenRouterService;
//# sourceMappingURL=openRouterService.js.map