---
name: detecting-flaky-tests
user-invocable: true
description: |
  フレーキーテスト（不安定なテスト）を検出・分類・修正支援するスキル。
  以下のような状況で使う：
  - 「テストが時々失敗する」「CI が時々落ちる」
  - 「同じコードなのにテスト結果が変わる」
  - 「flaky test」「不確定」「再実行すると通る」
  - 「テストが不安定」「テストの信頼性が低い」
  t-wada式TDDの信頼性基盤を守るために使用する。
  引数で実行回数を指定可能（デフォルト: 5回）。
---

# フレーキーテスト検出スキル

## 概要

テストスイートを複数回実行し、結果が一貫しないテスト（フレーキーテスト）を
自動検出・原因分類・修正提案するスキル。

**前提条件:**
- プロジェクトルートにテスト設定ファイルが存在すること
- テストランナーがインストールされていること
- 引数なしの場合は5回実行（`/flaky-test-detect 10` で10回に変更可能）

---

## コアワークフロー

### Step 1: テストランナーの自動検出

プロジェクトルートから以下の順で検出する：

```bash
# 検出優先順位
1. package.json の "scripts.test" を確認 → Jest / Vitest / Mocha
2. pytest.ini / pyproject.toml ([tool.pytest...]) / setup.cfg → pytest
3. Cargo.toml → cargo test
4. go.mod → go test
5. Makefile の test ターゲット → make test
```

**検出できない場合**: ユーザーに使用するテストコマンドを確認する。

検出したランナーと実行コマンドをユーザーに報告してから続行する。

### Step 2: ベースライン取得

テストを1回実行し、初期状態を記録する。

```bash
# pytest
pytest --tb=short -q 2>&1 | tee /tmp/flaky_run_0.txt

# Jest
npx jest --no-coverage --forceExit 2>&1 | tee /tmp/flaky_run_0.txt

# Vitest
npx vitest run --reporter=verbose 2>&1 | tee /tmp/flaky_run_0.txt

# cargo test
cargo test 2>&1 | tee /tmp/flaky_run_0.txt

# go test
go test ./... -v -count=1 2>&1 | tee /tmp/flaky_run_0.txt
```

**記録する情報:**
- 各テスト名とpass/fail状態
- 初回の失敗は「元々失敗している」テストとして記録（フレーキーではない）
- 実行時間（タイミング問題の検出に使用）

### Step 3: 反復実行

指定回数（N回）テストを逐次実行する。**並列実行は不可**（順序依存を検出するため）。

```bash
# 通常順序でN-1回
for i in $(seq 1 $((N-1))); do
  pytest --tb=short -q 2>&1 | tee /tmp/flaky_run_${i}.txt
done

# 最後の1回はランダム順序（pytest-randomly / jest --randomize）
pytest --tb=short -q --randomly-seed=12345 2>&1 | tee /tmp/flaky_run_${N}.txt
# Jest: npx jest --randomize 2>&1 | tee /tmp/flaky_run_${N}.txt
```

**注意**: テストが非常に多く時間がかかる場合は、ユーザーに確認してから続行する。

### Step 4: フレーキー判定と原因分類

全実行結果を比較し、フレーキーテストを特定する。

**フレーキー判定基準**: N回のうち1回以上、他の回と異なる結果（pass↔fail）が出たテスト。

**原因パターン分類**（`references/flaky-patterns.md` の6パターンを参照）:

| パターン | 検出の手がかり |
|---------|--------------|
| `TIMING` | asyncio/sleep/setTimeout/タイムアウトエラーを含む |
| `GLOBAL_STATE` | グローバル変数・モジュールレベル変数の変更を含む |
| `ORDERING` | ランダム順序実行時のみ失敗する |
| `EXTERNAL` | ネットワーク/ファイルIO/時刻取得を含む |
| `RESOURCE` | ポート使用・メモリ不足・一時ファイル競合 |
| `RANDOM` | random/Math.random/rand() を直接使用 |

各フレーキーテストのソースコードを読み、上記パターンに分類する。

### Step 5: レポート生成と修正提案

#### コンソール出力（必須）

```
Flaky Test Detection — {N} runs

FLAKY TESTS DETECTED ({count} tests):
─────────────────────────────────────
{test_name} ({file_path}:{line})
  Failure rate: {fail_count}/{N} ({pct}%)
  Pattern: {PATTERN}
  Cause: {具体的な原因の説明}
  Fix: {修正方針の一言説明}

STABLE TESTS: {stable_count}/{total_count} passed consistently
```

#### 詳細修正提案（コードレベル）

各フレーキーテストについて、`references/remediation.md` の対応パターンから
具体的な修正コードを提示する。

例（TIMING パターンの場合）:
```python
# Before (フレーキー):
import time
def test_delayed_response():
    time.sleep(0.1)  # 実行環境によってタイムアウト
    assert response.status == 200

# After (安定):
from unittest.mock import patch
def test_delayed_response():
    with patch('time.sleep'):  # sleep をモック化
        assert response.status == 200
```

#### FLAKY_REPORT.md 生成（オプション）

ユーザーに確認してからプロジェクトルートに生成する：

```markdown
# Flaky Test Report
Generated: {date}
Runs: {N}

## Summary
- Total tests: {total}
- Flaky tests: {flaky_count}
- Stable tests: {stable_count}

## Flaky Tests

### {test_name}
- File: {path}:{line}
- Failure rate: {rate}
- Pattern: {PATTERN}
- Root cause: ...
- Recommended fix: ...
```

---

## 呼び出し方の例

```
/flaky-test-detect          # デフォルト5回実行
/flaky-test-detect 10       # 10回実行
/flaky-test-detect 3        # 素早くチェック（3回）
```

---

## 品質チェックリスト

実行完了時に以下を確認する：

- [ ] テストランナーの検出結果をユーザーに報告したか
- [ ] ベースライン（初回）で失敗していたテストをフレーキーと混同していないか
- [ ] 各フレーキーテストのソースコードを実際に読んで分類したか
- [ ] 修正提案は具体的なコード例を含んでいるか
- [ ] STABLE なテスト数も報告したか（安心感の提供）

---

## エラー処理

| 状況 | 対応 |
|------|------|
| テストランナーが見つからない | ユーザーにコマンドを確認 |
| 全テストが元々失敗している | 「フレーキー検出前にビルドを修正してください」と報告 |
| テストが多すぎて時間がかかりそう | 実行前にユーザーに所要時間を見積もり確認 |
| 実行中に環境エラーが発生 | エラー内容を報告し、原因を RESOURCE パターンとして記録 |

---

## 関連スキル

- `tdd-cycle` — フレーキーテスト修正後の RED→GREEN→REFACTOR サイクル
- `coverage-gap` — カバレッジが低い箇所はフレーキー率と相関することが多い
- `/test` — 修正後の最終確認実行
- `planning-tests` — テスト設計レベルからフレーキー問題を防ぐ
