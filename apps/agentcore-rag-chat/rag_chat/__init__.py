"""agentcore-rag-chat の実装パッケージ。

このパッケージは「supervisor + 3 専門 RAG agent」のチャットを組み立てます。役割ごとに
モジュールを分け、本物の Amazon Bedrock / Knowledge Base / Memory を呼ばずに単体テスト
できるよう、依存（boto3 client・model・memory client）はすべて外から注入できる形にしています。

- config      : 環境変数から実行設定（generation model / 3 つの KB ID / Memory ID / region）を読む
- knowledge_base : 1 つの Knowledge Base を検索する Strands tool を kb_id 束縛で作る
- agents      : 専門 agent を tool 化（agents-as-tools）し、supervisor に束ねる
- memory      : AgentCore Memory の short-term（会話 event）保存・取得の薄いラッパ
- runtime     : AgentCore Runtime の entrypoint が呼ぶ純粋寄りの組み立てロジック
"""
