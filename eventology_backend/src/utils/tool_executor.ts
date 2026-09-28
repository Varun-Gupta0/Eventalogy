import type { ToolCall } from "@langchain/core/messages/tool";
import type { StructuredTool } from "@langchain/core/tools";

/**
 * Executes a tool call made by the LLM agent.
 *
 * In LangGraph 1.x / LangChain Core 1.x, tool.invoke() has strict overloaded
 * signatures that make passing tc.args directly a type error when the tool
 * array is heterogeneous. This helper casts to any for the invocation which
 * is safe because tc.name is matched against the tool array before calling.
 *
 * Always returns a string — either the tool result or a JSON error object.
 */
export async function executeTool(
  tools: StructuredTool[],
  tc: ToolCall
): Promise<string> {
  const matched = tools.find(t => t.name === tc.name);
  if (!matched) {
    return JSON.stringify({ error: `Tool "${tc.name}" not found in agent's tool list.` });
  }
  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const result = await (matched as any).invoke(tc.args);
    return typeof result === "string" ? result : JSON.stringify(result);
  } catch (err: any) {
    return JSON.stringify({ error: `Tool "${tc.name}" threw an error: ${err.message}` });
  }
}
