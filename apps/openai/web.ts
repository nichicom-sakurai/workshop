// apps/openai: OpenAI Agents SDK の最小 Web チャット UI (Bun.serve、依存ゼロ)。
//
// `mise run web openai` で起動し、ブラウザで http://localhost:3000 を開く。
// サーバ側で会話履歴を 1 本だけ保持し (ローカル単一ユーザ前提の割り切り)、
// run({ stream: true }) の toTextStream() をそのまま HTTP レスポンスにストリーミングする。
// OPENAI_API_KEY 未設定なら案内を表示して正常終了する。

import { Agent, run, type AgentInputItem } from "@openai/agents";

const apiKey = process.env.OPENAI_API_KEY?.trim();

if (!apiKey) {
  console.log(
    [
      "[INFO] OPENAI_API_KEY が未設定のため、Web チャットを起動できません。",
      "",
      "実行するには OpenAI API key を設定してください:",
      "  export OPENAI_API_KEY=sk-...",
      "  # または apps/openai/.env を作成 (.env.template を参照)",
    ].join("\n"),
  );
  process.exit(0);
}

const agent = new Agent({
  name: "Assistant",
  instructions:
    "You are a helpful assistant for the workshop monorepo. Answer concisely in the user's language.",
});

// ローカル単一ユーザ前提の会話履歴 (複数タブを開くと共有される — 学習用の割り切り)。
let history: AgentInputItem[] = [];

// フロントは web.ts と同じディレクトリの chat.html (cwd に依存せず解決)。
const html = await Bun.file(new URL("./chat.html", import.meta.url)).text();

const server = Bun.serve({
  port: Number(process.env.PORT ?? 3000),
  async fetch(req) {
    const url = new URL(req.url);

    if (req.method === "GET" && url.pathname === "/") {
      return new Response(html, {
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }

    if (req.method === "POST" && url.pathname === "/api/reset") {
      history = [];
      return new Response(null, { status: 204 });
    }

    if (req.method === "POST" && url.pathname === "/api/chat") {
      const { message } = (await req.json()) as { message?: string };
      const text = message?.trim();
      if (!text) {
        return new Response("message is required", { status: 400 });
      }

      const input: AgentInputItem[] = [...history, { role: "user", content: text }];
      const result = await run(agent, input, { stream: true });

      // ストリーム完了後に履歴を更新する (result.history は SDK が正しく整形する)。
      result.completed.then(() => {
        history = result.history;
      }).catch(() => {});

      // SDK の Node 互換ストリームをそのまま HTTP レスポンスにストリーミングする。
      return new Response(
        result.toTextStream({ compatibleWithNodeStreams: true }),
        { headers: { "content-type": "text/plain; charset=utf-8" } },
      );
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`OpenAI Agents Web チャット: http://localhost:${server.port}`);
console.log("停止するには Ctrl+C");
