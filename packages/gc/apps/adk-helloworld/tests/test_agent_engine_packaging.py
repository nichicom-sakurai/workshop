"""Agent Engine packaging の静的な整合性テスト（stdlib のみ、新規依存なし）。

実行（README の方法）:
  mise exec -- uv run --directory packages/gc/apps/adk-helloworld --locked \
    python -m unittest discover -s tests

このテストは Agent Engine 用の committed ファイル（agent-engine/）を **import せず
テキストとして検証**する。agent_engine_app.py は vertexai を import するが、
それはローカル .venv に入れない（archive の requirements.txt 側にだけ入る）ため、
ここで import するとローカルでは ImportError になる。よって静的検査に留める。

検証する不変条件:
  - requirements.txt の google-adk pin が pyproject.toml の dependencies と一致する
    （バージョンの単一の真実を 2 ファイル間で守る。Dockerfile↔mise.toml と同じ流儀）。
  - requirements.txt が Agent Engine runtime 依存（aiplatform[agent_engines]）を含む。
  - entrypoint(agent_engine_app.py)が AdkApp ラッパーと root_agent を参照し、
    Terraform 側 python_spec が指す変数名 `agent_engine` を公開している。
"""

import re
import tomllib
import unittest
from pathlib import Path

# このテストファイル(tests/)の 1 つ上 = app ルート。cwd に依存せず解決する。
APP_DIR = Path(__file__).resolve().parent.parent
PYPROJECT = APP_DIR / "pyproject.toml"
REQUIREMENTS = APP_DIR / "agent-engine" / "requirements.txt"
ENTRYPOINT = APP_DIR / "agent-engine" / "agent_engine_app.py"


def _pyproject_google_adk_pin() -> str:
    """pyproject.toml の dependencies から google-adk の pin 文字列を返す。"""
    data = tomllib.loads(PYPROJECT.read_text(encoding="utf-8"))
    deps = data["project"]["dependencies"]
    for dep in deps:
        # "google-adk==2.2.0" のような厳密 pin を想定する。
        if re.match(r"^google-adk\b", dep.strip()):
            return dep.strip()
    raise AssertionError("pyproject.toml の dependencies に google-adk が無い")


def _requirements_lines() -> list[str]:
    """requirements.txt の非空・非コメント行のリストを返す。"""
    lines = []
    for raw in REQUIREMENTS.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            lines.append(line)
    return lines


class AgentEnginePackagingTest(unittest.TestCase):
    def test_google_adk_pin_matches_pyproject(self):
        # archive の requirements.txt と pyproject.toml で google-adk の pin が一致する。
        pin = _pyproject_google_adk_pin()
        adk_lines = [ln for ln in _requirements_lines() if ln.startswith("google-adk")]
        self.assertEqual(
            adk_lines,
            [pin],
            "agent-engine/requirements.txt の google-adk は pyproject.toml と一致させる",
        )

    def test_google_adk_pin_is_exact(self):
        # 「latest/any 禁止」方針: google-adk は == の厳密 pin であること。
        self.assertIn("==", _pyproject_google_adk_pin())

    def test_requirements_includes_agent_engines_runtime(self):
        # Agent Engine runtime 依存（vertexai.agent_engines / AdkApp の供給元）を含む。
        joined = "\n".join(_requirements_lines())
        self.assertRegex(joined, r"google-cloud-aiplatform\[agent[_-]engines\]==")

    def test_entrypoint_wraps_root_agent_with_adkapp(self):
        # entrypoint は raw root_agent ではなく AdkApp ラッパーを公開する（#1 footgun）。
        src = ENTRYPOINT.read_text(encoding="utf-8")
        self.assertIn("AdkApp", src)
        self.assertIn("from hello_world.agent import root_agent", src)
        # Terraform の entrypoint_object = "agent_engine" が指す変数を公開している。
        self.assertRegex(src, r"\bagent_engine\s*=\s*AdkApp\(")

    def test_entrypoint_object_name_is_stable(self):
        # entrypoint_object 名（agent_engine）は Terraform 側と固定。誤改名を検出する。
        src = ENTRYPOINT.read_text(encoding="utf-8")
        self.assertRegex(src, r"\bagent_engine\b\s*=\s*AdkApp\(")


if __name__ == "__main__":
    unittest.main()
