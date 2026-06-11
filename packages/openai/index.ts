// packages/openai: OpenAI Agents SDK (TypeScript) の最小 HelloWorld サンプル。
//
// - OPENAI_API_KEY が未設定なら設定方法を案内して正常終了する (exit 0)。
//   これにより `mise run dev:all` が API key 無しでも途中で失敗しない。
// - API key がある場合のみ SDK を動的 import し、Agent と run で 1 回だけ実行する。
//   未設定時のパスを SDK の読み込みから切り離し、案内表示と exit 0 を確実にする。

const apiKey = process.env.OPENAI_API_KEY?.trim();

if (!apiKey) {
  console.log(
    [
      "[INFO] OPENAI_API_KEY が未設定のため、agent 実行をスキップしました。",
      "",
      "実行するには OpenAI API key を設定してください:",
      "  export OPENAI_API_KEY=sk-...",
      "  # または packages/openai/.env を作成 (.env.template を参照)",
      "",
      "任意で OPENAI_DEFAULT_MODEL を設定すると model を上書きできます。",
    ].join("\n"),
  );
  process.exit(0);
}

try {
  // model は明示せず SDK default を使う (OPENAI_DEFAULT_MODEL で上書き可)。
  const { Agent, run } = await import("@openai/agents");

  const agent = new Agent({
    name: "Assistant",
    instructions: "You are a helpful assistant. Answer in one short sentence.",
  });

  const result = await run(agent, "Say hello to the workshop monorepo.");

  console.log(result.finalOutput ?? "[INFO] agent から出力が得られませんでした。");
} catch (error) {
  console.error(
    "[NG] agent 実行に失敗しました:",
    error instanceof Error ? error.message : error,
  );
  process.exit(1);
}
