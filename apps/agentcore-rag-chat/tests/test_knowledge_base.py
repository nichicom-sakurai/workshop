"""knowledge_base（KB 検索）の unittest。本物の Bedrock は呼ばず fake client を注入する。"""

import unittest

from rag_chat.knowledge_base import (
    format_retrieval_results,
    make_kb_search_tool,
    search_kb,
)


class FakeRuntimeClient:
    """bedrock-agent-runtime の retrieve を模した fake。呼び出し引数を記録する。"""

    def __init__(self, response):
        self.response = response
        self.calls = []

    def retrieve(self, **kwargs):
        self.calls.append(kwargs)
        return self.response


def _response(*texts):
    return {"retrievalResults": [{"content": {"text": t}} for t in texts]}


class FormatRetrievalResultsTest(unittest.TestCase):
    def test_joins_text_chunks(self):
        result = format_retrieval_results(_response("alpha", "beta"))
        self.assertEqual(result, "alpha\n\nbeta")

    def test_empty_returns_placeholder(self):
        self.assertIn("No relevant information", format_retrieval_results({}))
        self.assertIn("No relevant information", format_retrieval_results({"retrievalResults": []}))

    def test_skips_malformed_entries(self):
        response = {"retrievalResults": [{"content": {}}, {"content": {"text": "  "}}, {"content": {"text": "ok"}}]}
        self.assertEqual(format_retrieval_results(response), "ok")


class SearchKbTest(unittest.TestCase):
    def test_builds_expected_retrieve_request(self):
        client = FakeRuntimeClient(_response("chunk"))
        result = search_kb(client, "kb-123", "what is ec2?", num_results=3)
        self.assertEqual(result, "chunk")
        self.assertEqual(len(client.calls), 1)
        call = client.calls[0]
        self.assertEqual(call["knowledgeBaseId"], "kb-123")
        self.assertEqual(call["retrievalQuery"], {"text": "what is ec2?"})
        self.assertEqual(
            call["retrievalConfiguration"],
            {"vectorSearchConfiguration": {"numberOfResults": 3}},
        )


class MakeKbSearchToolTest(unittest.TestCase):
    def test_returns_tool_without_creating_boto3_client(self):
        # client を注入しているので boto3 を一切呼ばずに tool を生成できる。
        tool_obj = make_kb_search_tool("kb-123", "ap-northeast-1", client=FakeRuntimeClient(_response("x")))
        self.assertIsNotNone(tool_obj)


if __name__ == "__main__":
    unittest.main()
