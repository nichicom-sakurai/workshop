import os
import unittest
from unittest.mock import patch

from main import build_response, get_prompt, missing_model_error


class AgentCoreStrandsBasicTest(unittest.TestCase):
    def test_get_prompt_accepts_prompt_key(self):
        self.assertEqual(get_prompt({"prompt": "Hello"}), "Hello")

    def test_get_prompt_falls_back_to_helpful_message(self):
        self.assertEqual(
            get_prompt({}),
            "No prompt found. Send JSON with a prompt field.",
        )

    def test_missing_model_error_is_json_compatible(self):
        self.assertEqual(
            missing_model_error(),
            {
                "status": "error",
                "error": "BEDROCK_MODEL_ID is not set",
            },
        )

    def test_build_response_uses_injected_responder(self):
        def fake_responder(prompt: str) -> str:
            return f"echo: {prompt}"

        with patch.dict(os.environ, {"BEDROCK_MODEL_ID": "test-model"}, clear=False):
            self.assertEqual(
                build_response({"prompt": "Hello"}, responder=fake_responder),
                {
                    "status": "success",
                    "response": "echo: Hello",
                    "model_id": "test-model",
                },
            )

    def test_build_response_returns_error_without_model_id(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(build_response({"prompt": "Hello"}), missing_model_error())


if __name__ == "__main__":
    unittest.main()
