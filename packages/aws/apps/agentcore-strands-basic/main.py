import os
from collections.abc import Callable
from typing import Any

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.models import BedrockModel

app = BedrockAgentCoreApp()


def get_prompt(payload: dict[str, Any]) -> str:
    prompt = payload.get("prompt")
    if isinstance(prompt, str) and prompt.strip():
        return prompt

    return "No prompt found. Send JSON with a prompt field."


def missing_model_error() -> dict[str, str]:
    return {
        "status": "error",
        "error": "BEDROCK_MODEL_ID is not set",
    }


def invoke_bedrock_agent(prompt: str) -> str:
    model_id = os.environ["BEDROCK_MODEL_ID"]
    region_name = os.environ.get("AWS_DEFAULT_REGION") or os.environ.get("AWS_REGION")
    model = BedrockModel(model_id=model_id, region_name=region_name)
    agent = Agent(
        model=model,
        system_prompt=(
            "You are a concise assistant running inside Amazon Bedrock "
            "AgentCore Runtime. Answer the user in one or two sentences."
        ),
    )

    return str(agent(prompt))


def build_response(
    payload: dict[str, Any],
    responder: Callable[[str], str] | None = None,
) -> dict[str, str]:
    model_id = os.environ.get("BEDROCK_MODEL_ID")
    if not model_id:
        return missing_model_error()

    prompt = get_prompt(payload)
    response = (responder or invoke_bedrock_agent)(prompt)

    return {
        "status": "success",
        "response": response,
        "model_id": model_id,
    }


@app.entrypoint
def invoke(payload: dict[str, Any]) -> dict[str, str]:
    return build_response(payload)


if __name__ == "__main__":
    app.run()
