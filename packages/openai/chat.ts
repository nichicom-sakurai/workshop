// packages/openai: OpenAI Agents SDK のターミナル対話チャット (マルチターン)。
//
// `mise run chat openai` で起動。OPENAI_API_KEY が未設定なら案内して正常終了する。
// 各ターンで run() に直前までの会話履歴 (result.history) を渡し、文脈を維持する。
// 空行 / Ctrl+D / "/exit" で終了する。

import { Agent, run, type AgentInputItem } from "@openai/agents";

const apiKey = process.env.OPENAI_API_KEY?.trim();

if (!apiKey) {
  console.log(
    [
      "[INFO] OPENAI_API_KEY が未設定のため、チャットを開始できません。",
      "",
      "実行するには OpenAI API key を設定してください:",
      "  export OPENAI_API_KEY=sk-...",
      "  # または packages/openai/.env を作成 (.env.template を参照)",
    ].join("\n"),
  );
  process.exit(0);
}

const agent = new Agent({
  name: "Assistant",
  instructions:
    "You are a helpful assistant for the workshop monorepo. Answer concisely in the user's language.",
});

// 会話履歴 (前ターンの入力 + 生成された応答) を保持し、毎回 run() に渡す。
let history: AgentInputItem[] = [];

console.log("OpenAI Agents チャット — 空行 / Ctrl+D / /exit で終了");

while (true) {
  const text = prompt("You:")?.trim();
  if (!text || text === "/exit") break;

  const input: AgentInputItem[] = [...history, { role: "user", content: text }];

  try {
    const result = await run(agent, input);
    console.log(`AI: ${result.finalOutput ?? "(出力が得られませんでした)"}`);
    history = result.history; // 次ターンへ会話を引き継ぐ
  } catch (error) {
    console.error(
      "[NG] 応答に失敗しました:",
      error instanceof Error ? error.message : error,
    );
  }
}

console.log("チャットを終了しました。");
