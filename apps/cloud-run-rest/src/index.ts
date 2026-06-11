// Cloud Run container contract に従う最小 REST service:
// - `PORT` 環境変数で指定された port で listen する（未設定なら 8080）
// - 全 interface（0.0.0.0）で listen する
// https://docs.cloud.google.com/run/docs/container-contract
// Bun の default に依存せず port / hostname を明示し、contract 準拠をコードで示します。

// 不正な PORT（非数値・範囲外）のまま起動すると、Bun.serve は「port 未指定」として
// 任意の port を採番し、Cloud Run 上では $PORT で listen しない不可解な deploy 失敗に
// なります。contract 違反へ静かに退化しないよう、起動時に検証して fail-fast します。
const rawPort = process.env.PORT ?? "8080";
const port = Number(rawPort);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error(`[NG] invalid PORT: ${JSON.stringify(rawPort)} (1-65535 の整数を指定してください)`);
  process.exit(1);
}

const server = Bun.serve({
  port,
  hostname: "0.0.0.0",
  fetch(request) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/") {
      return Response.json({
        message: "Hello from cloud-run-rest",
        // Cloud Run が注入する revision / service 名。local 実行では null になります。
        // https://docs.cloud.google.com/run/docs/container-contract#services-env-vars
        revision: process.env.K_REVISION ?? null,
        service: process.env.K_SERVICE ?? null,
      });
    }
    return Response.json({ error: "not found" }, { status: 404 });
  },
});

console.log(`listening on http://${server.hostname}:${server.port}`);
