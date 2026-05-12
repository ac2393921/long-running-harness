---
name: fix-debt
description: Iteratively detects and auto-fixes technical debt in a codebase using three quality criteria from debt-analysis references: conditional branch simplification, encapsulation, and separation of concerns. Applies fixes directly to code, runs existing tests to verify no regressions, re-analyzes, and loops until all high-severity issues are resolved or max iterations (5) reached. Use this skill when you want to automatically improve code quality with real code changes, reduce technical debt systematically, or clean up code to meet quality standards. Trigger on phrases like "fix technical debt", "clean up code quality", "refactor and fix issues", "improve code quality automatically", "apply debt fixes", "fix code problems", "eliminate debt".
---

## 概要

このスキルは `debt-analysis` の分析基準を用いてコードベースの技術的負債を**自動修正**する。
分析 → 修正 → テスト実行 → 再分析 のループを、🔴高severity問題がゼロになるまで繰り返す。

## Step 1: 分析基準のロード

以下を順に読み込む（全て必須）。debt-analyser サブエージェントは使用しない（このスキルが直接参照する）:

1. `references/conditional-branch.md` — 条件分岐改善パターン（早期return、else排除）
2. `references/encapsulation.md` — カプセル化違反の8つの検出基準
3. `references/soc-overview.md` — 関心の分離の概要
4. `references/soc-patterns-main.md` — SoCの主要3パターン
5. `references/soc-patterns-additional.md` — SoCの追加2パターン
6. `references/soc-analysis-guide.md` — SoC分析の5ステップガイド

## Step 2: 対象の特定

- 引数が指定されていればそのパスを対象とする
- tdd-cycleから呼び出されていた場合は修正したファイルを対象とする
- 指定なしの場合は現在のワーキングディレクトリ（CWD）全体

## Step 3: 初期分析

対象コードを全3基準で分析し、以下の形式で問題リストを作成する:

```
問題リスト:
ID | 🔴/🟡/🟢 | 基準 | ファイル:行 | 問題の概要
─────────────────────────────────────────
1  | 🔴 高   | 条件分岐 | src/foo.py:23 | 3段ネストのif文
2  | 🔴 高   | カプセル化 | src/bar.py:10 | publicフィールド + 貧血モデル
3  | 🟡 中   | SoC | src/baz.py:50 | 3つの異なる責務が混在
```

深刻度判定（`references/soc-analysis-guide.md` の基準に従う）:
- 🔴 高: 5つ以上の関心事 / God Object / 重大なカプセル化違反 / 4段以上のネスト
- 🟡 中: 3-4の関心事 / 中程度のネスト / 貧血モデル / Primitive Obsession
- 🟢 低: 軽微なネスト / 命名問題 / Demeter法則の軽微な違反

## Step 4: 修正ループ（最大5イテレーション）

**ループ継続条件**: 🔴高severity問題が残っている かつ イテレーション < 5

各イテレーションで以下を実行:

### 4a. 問題の選択

高severity問題の中から、影響範囲が最も小さいもの（単一ファイル内で完結する問題）から優先的に選択する。

### 4b. 修正方針の決定

選択した問題の基準に応じて `references/` から対応パターンを参照し、具体的な修正コードを決定する:

- **条件分岐** → `conditional-branch.md` のパターン（早期return、ガード節）
- **カプセル化** → `encapsulation.md` の該当項目（完全コンストラクタ、Value Object等）
- **SoC** → `soc-patterns-main.md` / `soc-patterns-additional.md` の対応パターン

### 4c. コードの修正

`Edit` または `Write` ツールで実際にコードを修正する。修正時の制約:

- 1ファイルあたり最大3問題を1回のイテレーションで修正（過度な変更を防ぐ）。複数ファイルを同一イテレーション内で修正してよい
- 修正後もコンパイル/文法エラーが起きないことを優先する
- 型シグネチャやAPIの変更は呼び出し元も更新する
- **テストファイルの扱い**: ソースのインターフェース変更に伴う既存テストの Edit/Replace（更新）は許可。テストの Delete（削除）は禁止

### 4d. テスト実行

修正後、プロジェクトの言語に応じてテストを実行する:

```bash
# Python
pytest              # または python -m pytest
python -m unittest  # pytestがなければ

# Go
go test ./...

# Rust
cargo test

# JavaScript / TypeScript
npm test            # または bun test, yarn test

# Java
mvn test            # または gradle test
```

テストファイルが見つからない場合は「テストが存在しないため、リグレッション確認ができません」とユーザーに伝え、修正は続行する。

### 4e. テスト結果の処理

**テスト成功** → その問題に「✅ 修正済み」フラグを立てて次の問題へ

**テスト失敗** → その修正をリバートしてから、問題に「⚠️ 修正不可（テスト失敗）」フラグを立てて次の問題へ。リバートは該当ファイルを修正前の状態に戻すことで行う。

### 4e-extra. 中間状態の保存

テスト結果を処理した後、`~/.claude/reports/fix-debt-state.json` へ現在の状態を書き出す（セッション中断時の再開用）:

```json
{
  "iteration": <現在のイテレーション番号>,
  "target": "<対象パス>",
  "remaining_high": ["<ファイル:行>", ...],
  "fixed": ["<ファイル:行>", ...],
  "unfixable": ["<ファイル:行>", ...]
}
```

### 4f. 再分析（Uncorrelated Evaluator）

全高severity問題を試みたら、以下の3エージェントを**並列起動**して再評価を委任する。
修正したエージェント自身が再評価すると Self-leniency（甘い評価）が生じるため、必ず独立したエージェントに委任すること。

```
並列実行:
  ├── debt-analyser サブエージェント
  │     入力: 対象ファイルパス
  │     指示: 修正の副作用チェック — 新たに発生した高severity問題（条件分岐・カプセル化・SoC）を報告せよ
  │
  ├── code-reviewer サブエージェント
  │     入力: 対象ファイルパス
  │     指示: コード品質（設計・可読性・TDD・パフォーマンス）の観点で Critical 問題を報告せよ
  │
  └── security-reviewer サブエージェント
        入力: 対象ファイルパス
        指示: OWASP Top 10・インジェクション・シークレット漏洩を確認し Critical 問題を報告せよ
```

3エージェントのいずれかで Critical が検出された場合は、次のイテレーションの問題リストに追加する。

## Step 5: 完了チェック

ループ終了後、以下の順で確認:

1. **高severity問題がゼロ** → ✅ 完了。最終レポートを生成する
2. **イテレーション上限（5回）到達** → ⚠️ 上限到達。残存問題を含む最終レポートを生成する
3. **全高severity問題が修正不可** → ❌ 自動修正困難。手動対応が必要な問題を含む最終レポートを生成する

## Step 6: 最終レポートの生成

**出力先**: `~/.claude/reports/fix-debt-YYYYMMDD-HHMMSS.md`（絶対パス。`~/` はホームディレクトリ）

`~/.claude/reports/` ディレクトリが存在しない場合は作成する。

`~/.claude/skills/fix-debt/references/report-template.md` が存在すればその形式を使う。存在しない場合は以下の形式で直接生成する:

```markdown
# fix-debt レポート YYYYMMDD-HHMMSS

## 完了ステータス
✅ 完了 / ⚠️ 上限到達 / ❌ 修正不可

## 修正済み問題
| ID | ファイル:行 | 基準 | 適用パターン | Iter |
|---|---|---|---|---|

## 残存問題（中・低severity）
- ...

## 修正不可だった問題
- ...（なければ「なし」）

## 推奨アクションプラン
- ...
```
