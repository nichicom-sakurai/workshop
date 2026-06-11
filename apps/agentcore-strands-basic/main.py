"""Amazon Bedrock AgentCore Runtime 上で動く、最小構成の AI agent。

処理の流れ（おおまかなイメージ）:
    リクエスト(JSON) → invoke() → build_response() →
    invoke_bedrock_agent() が Bedrock model を呼ぶ → 結果(JSON) を返す

この三連引用符 (\"\"\" ... \"\"\") で囲んだ文字列は「docstring」と呼ばれ、
ファイルや関数の先頭に置くと「説明書き」として扱われる Python の慣習です。
"""

# --- import: このファイルで使う機能を読み込む ---

# os: OS の機能を使う標準ライブラリ。ここでは環境変数 (os.environ) の読み取りに使う。
import os

# Callable: 「関数」を表す型ヒント。引数として関数を受け取りたいときに使う。
# collections.abc は Python に最初から入っている標準ライブラリ。
from collections.abc import Callable

# Any: 「どんな型でもよい」を表す型ヒント。中身の型が定まらない値に使う。
from typing import Any

# 以下は外部パッケージ（pyproject.toml で依存に追加したもの）からの import。
# BedrockAgentCoreApp: このアプリを AgentCore Runtime 上で動かすための土台。
from bedrock_agentcore.runtime import BedrockAgentCoreApp

# Agent: 「AI エージェント」本体。model に質問を投げて答えを受け取る。
from strands import Agent

# BedrockModel: Amazon Bedrock の model を Agent から使えるようにするラッパー。
from strands.models import BedrockModel

# アプリ本体のインスタンスを 1 つ作る。
# このあと @app.entrypoint や app.run() のように、この app を通して使う。
app = BedrockAgentCoreApp()


# def は「関数を定義する」キーワード。
# payload: dict[str, Any] は「引数 payload は、キーが文字列・値は任意の型の辞書(dict)」という型ヒント。
# -> str は「この関数は文字列(str)を返す」という戻り値の型ヒント。
# ※ 型ヒントはあくまで注釈で、Python は実行時に強制チェックはしない（読みやすさと支援のため）。
def get_prompt(payload: dict[str, Any]) -> str:
    """payload から prompt（ユーザーの質問文）を取り出す。無ければ案内文を返す。"""
    # dict の .get("キー") は、キーが無ければエラーではなく None を返す安全な取り出し方。
    prompt = payload.get("prompt")

    # isinstance(値, 型) は「値がその型かどうか」を判定する。
    # str.strip() は前後の空白を除いた文字列を返す。空文字列 "" は if で False 扱いになるため、
    # 「文字列であり、かつ空白だけではない」場合に prompt をそのまま返す。
    if isinstance(prompt, str) and prompt.strip():
        return prompt

    # 上の条件を満たさなかった場合（prompt が無い・空など）に返す案内文。
    return "No prompt found. Send JSON with a prompt field."


def missing_model_error() -> dict[str, str]:
    """model ID が未設定だったときに返すエラー用の辞書(dict)を作る。"""
    # {} で辞書を作る。"キー": 値 の形で並べる。
    # この辞書はそのまま JSON として返せる形になっている。
    return {
        "status": "error",
        "error": "BEDROCK_MODEL_ID is not set",
    }


def invoke_bedrock_agent(prompt: str) -> str:
    """実際に Amazon Bedrock の model を呼び出し、回答の文字列を返す。"""
    # os.environ["キー"] は環境変数の読み取り。キーが無いと KeyError で停止する（必須の設定）。
    model_id = os.environ["BEDROCK_MODEL_ID"]

    # or は「左が空(None/falsy)なら右を使う」短絡評価。
    # AWS_DEFAULT_REGION が無ければ AWS_REGION を使い、どちらも無ければ None になる。
    # （.get() なのでキーが無くてもエラーにならない点が上の [] との違い）
    region_name = os.environ.get(
        "AWS_DEFAULT_REGION") or os.environ.get("AWS_REGION")

    # 使う model（どの Bedrock model か・どの region か）を組み立てる。
    model = BedrockModel(model_id=model_id, region_name=region_name)

    # Agent を作る。system_prompt は AI への「振る舞いの指示」。
    # 丸括弧 ( ) で囲んで文字列を改行して並べると、自動で 1 つの文字列に連結される。
    agent = Agent(
        model=model,
        system_prompt=(
            "You are a concise assistant running inside Amazon Bedrock "
            "AgentCore Runtime. Answer the user in one or two sentences."
        ),
    )

    # agent(prompt) のように agent を関数のように呼ぶと、model に質問を投げて結果を受け取れる。
    # 戻り値は文字列とは限らないため、str(...) で文字列に変換してから返す。
    return str(agent(prompt))


def build_response(
    payload: dict[str, Any],
    # responder は「prompt(str) を受け取り str を返す関数」を渡せる引数。
    # | None は「その型 または None」を意味し、= None は「省略時の初期値は None」。
    # これは依存性注入(DI)の形で、テスト時に本物の Bedrock 呼び出しの代わりに
    # 偽の関数を差し込めるようにするための工夫（tests/test_main.py 参照）。
    responder: Callable[[str], str] | None = None,
) -> dict[str, str]:
    """リクエストを受け取り、最終的に返す JSON 相当の辞書(dict)を組み立てる。"""
    # ここは [] ではなく .get() を使い、未設定なら None にして自前でエラー応答を返す。
    model_id = os.environ.get("BEDROCK_MODEL_ID")

    # not model_id は「model_id が None または空文字なら True」。未設定ならエラー応答を返す。
    if not model_id:
        return missing_model_error()

    # payload から質問文を取り出す。
    prompt = get_prompt(payload)

    # responder が渡されていればそれを、無ければ本物の invoke_bedrock_agent を使う（or の短絡評価）。
    # 直後に (prompt) を付けて、選ばれた関数をその場で呼び出している。
    response = (responder or invoke_bedrock_agent)(prompt)

    # 成功時の応答を辞書で返す。
    return {
        "status": "success",
        "response": response,
        "model_id": model_id,
    }


# @app.entrypoint は「デコレータ」。直下の関数に機能を付け加える Python の仕組み。
# これにより invoke() が AgentCore Runtime からの「入口（呼び出される関数）」として登録される。
@app.entrypoint
def invoke(payload: dict[str, Any]) -> dict[str, str]:
    """AgentCore Runtime から呼ばれる入口。中身は build_response に委譲する。"""
    return build_response(payload)


# __name__ は Python の特別な変数。
# このファイルを `python main.py` のように直接実行したときだけ "__main__" になる。
# （他ファイルから import されたときは実行されない）→ ローカルでアプリを起動するための入口。
if __name__ == "__main__":
    # app.run() (uvicorn) は既定で起動ログを出さないため、起動を知らせるバナーを出力する。
    model_id = os.environ.get("BEDROCK_MODEL_ID")
    app.run()
