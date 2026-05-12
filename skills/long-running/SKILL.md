---
name: long-running
description: Planner→Builder→EvaluatorのLong-Runningエージェントハーネスで複雑なタスクを実装します。plannerがfeatures.jsonに機能を分解し、builderがTDDで1機能ずつ実装し、evaluatorがPASSするまでbuilderを繰り返します。「〇〇を作って」「実装して」「long-running」などのリクエストで起動します。
user-invocable: true
---

# Long-Running Agent Harness（Planner → Builder → Evaluator）

3つの専門エージェントをループ構造で連携し、複雑なタスクを品質保証しながら実装します。

```
Planner ──→ Builder ──→ Evaluator
               ↑  NEEDS REVISION  │
               └──────────────────┘ (最大3回/機能)

全 feature PASS → FINAL-SUMMARY
```

> **Harness（orchestrator）とは**: このスキルを実行しているセッション自身（Claude Code の main セッション）がハーネスです。ハーネスは `Agent` ツールで各専門エージェントを順次起動し、フェーズ間で `features.json` の状態管理を担います。Planner・Builder・Evaluator はそれぞれ別の `Agent(subagent_type="planner" / "builder" / "evaluator")` 呼び出しとして起動されます。

---

## 使用しない場面

- 単一ファイルの修正・typo 修正など、1エージェントで完結するタスク
- 調査・計画なしに即座に実行できる小さな変更

迷ったら: 「機能を複数に分解できるか？」を問え。NOなら本スキル不要。

---

## 設計原則

### Shallow Plans 防止
`planner` エージェントが Read/Grep/Glob のみでじっくり仕様をほぐしてから `builder` へ渡す。

### Context Rot 防止
1機能 = 1セッション原則。状態は `features.json` に外部化し、新しいコンテキストでは JSON を読み直して再開する。

### Uncorrelated Evaluator
`evaluator` エージェントは `builder` のコンテキストを一切引き継がない新規エージェントとして起動する。Self-leniency（実装者による甘い自己評価）を防ぐ。

---

## 共通制約（全フェーズ適用）

> ⚠️ **Context anxiety 対策**: コンテキスト制限に近づいても、タスクを「完了」とマークしてはならない。
> 必ず外部ファイルに現在状態を保存してから `/compact` すること。

---

## セッションディレクトリ

同一リポジトリで複数タスクを並行・逐次に扱えるよう、実行ごとにサブディレクトリを切る。

```
.claude/orchestrate/
├── {session-slug}/          ← タスクごとのディレクトリ
│   ├── features.json
│   ├── plan.md
│   ├── builder-notes-*.md
│   ├── evaluation-*.md
│   ├── FINAL-SUMMARY.md
│   └── skill-usage.json
└── {another-session}/
    └── ...
```

**session-slug の決め方**:
1. ユーザーがタスク名を指定した場合: `{kebab-case-task-name}` （例: `user-auth`）
2. 指定なしの場合: `{YYYY-MM-DD}-{kebab-case-task-name}` （例: `2026-05-12-user-auth`）
3. 再開する場合: 既存の session-slug を指定してそのディレクトリを使う

**起動時の処理**:
- 既存セッション一覧を `ls .claude/orchestrate/` で確認し、再開候補があればユーザーに提示する
- 新規の場合はユーザーからタスク名を確認して session-slug を決定する

---

## 中央ハンドオフアーティファクト: features.json

全エージェントの共有状態ファイル。`.claude/orchestrate/{session-slug}/features.json` に配置する。

`planner` エージェントが生成するスキーマに、harness がランタイム状態フィールドを追加する:

```json
{
  "version": "1.0",
  "metadata": {
    "plan_ref": "plan.md",
    "generated_at": "ISO8601"
  },
  "features": [
    {
      "id": "FEATURE-001",
      "name": "機能名",
      "sequence": 1,
      "description": "詳細説明",
      "scope": {
        "files_to_create": [],
        "files_to_modify": [],
        "files_to_delete": []
      },
      "acceptance_criteria": ["テスト項目1", "テスト項目2"],
      "test_strategy": {
        "unit_tests": ["test_foo_success"],
        "integration_tests": [],
        "edge_cases": ["invalid_input"]
      },
      "pre_conditions": [],
      "post_conditions": [],
      "rollback_strategy": "緊急対応手順",
      "status": "pending",
      "loop": 0,
      "evaluator_feedback": null
    }
  ],
  "implementation_notes": {
    "skill_usage_ref": ".claude/orchestrate/skill-usage.json",
    "context_checkpoints": [
      {
        "after_feature": "FEATURE-001",
        "save_artifacts": ["src/example.py", "tests/test_example.py"]
      }
    ]
  }
}
```

**status の遷移**:
```
pending → in_progress → done
                      → blocked  (loop >= 3 かつ NEEDS REVISION 残存)
```

---

## フェーズ定義

### Phase 1: Planner（計画）

**エージェント**: `planner`  
**目的**: タスクを最小機能単位に分解し `features.json` と `plan.md` を生成する  
**出力**:
- `.claude/orchestrate/{session-slug}/plan.md`（15セクション実装計画）
- `.claude/orchestrate/{session-slug}/features.json`（builder への入力）

実行内容:
- `planner` エージェントは内部で `issue-plan` スキルを使用して計画を作成する
- Read/Grep/Glob のみ使用（コード修正禁止）
- `features.json` の各 feature に `status: "pending"`, `loop: 0`, `evaluator_feedback: null` を追加する

完了後:
1. `features.json` をユーザーに提示し承認を得る
2. 未決定項目がある場合は `AskUserQuestion` で確認してから進む
3. 承認されたら Builder フェーズへ進む

---

### Phase 2: Builder（実装）

**エージェント**: `builder`  
**目的**: `features.json` の `status: "pending"` な feature を **1件だけ** TDD で実装する  
**出力**: コード変更 + `.claude/orchestrate/{session-slug}/builder-notes-{FEATURE-ID}.md`

実行内容:
1. `features.json` を読み込み、`status: "pending"` かつ `pre_conditions` の feature が全て `done` なものを `sequence` 順に1件選択する
2. `features.json` の該当 feature の `status` を `"in_progress"` に更新する
3. `builder` エージェントは内部で `build-cycle` スキルを使用して TDD 実装する
4. 実装ノートを `builder-notes-{FEATURE-ID}.md` に保存する

> **builder エージェントへ渡すプロンプトには必ず SESSION_DIR を含めること**:
> ```
> SESSION_DIR: .claude/orchestrate/{session-slug}
> features.json のパス: {SESSION_DIR}/features.json
> skill-usage.json のパス: {SESSION_DIR}/skill-usage.json
> 出力ノート: {SESSION_DIR}/builder-notes-{FEATURE-ID}.md
> ```
> build-cycle スキルは `features.json` を相対パスで参照するため、エージェントは作業ルートから当該パスで読むこと。

`evaluator_feedback` がある場合（ループバック時）:
- `features.json` の `evaluator_feedback` を読み、指摘事項に対応する
- ノートはバージョン管理: `builder-notes-{FEATURE-ID}-v{N}.md`（上書き禁止）

完了後: `builder-notes-{FEATURE-ID}.md` を保存し、Evaluator フェーズへ渡す

---

### Phase 3: Evaluator（評価）

**エージェント**: `evaluator`

> ⚠️ **Uncorrelated Evaluator**: `evaluator` エージェントは `builder` のコンテキストを一切引き継がない。
> 新規エージェントとして起動すること。Self-leniency 防止が目的。

**目的**: 実装した feature を4軸ルーブリックで定量評価し、Builder ループを制御する  
**入力**:
- `features.json`（feature の acceptance_criteria・DoD）
- `builder-notes-{FEATURE-ID}.md`
- 変更されたコード
- `plan.md`（DoD セクション参照用）

**出力**: `.claude/orchestrate/evaluation-{FEATURE-ID}.md`

**evaluator エージェントの評価軸（4軸×5段階）**:

| 軸 | 概要 | PASS 基準 |
|---|---|---|
| 機能性 | DoD・AC 達成度 / Playwright UI 検証 | 全 DoD 項目達成、主要機能すべてOK |
| 技術的実行 | テストカバレッジ・コード品質・全テスト PASS | カバレッジ ≥ 70%、全テスト PASS |
| デザイン品質 | 視覚一貫性・UX・アクセシビリティ（FE のみ） | 基本レイアウトOK（N/A 許容） |
| 独創性 | 問題解決のアプローチ・コードの洗練度 | 標準的な実装以上 |

**総合スコアの計算**: 4 軸の算術平均（各軸 1〜5 点）。デザイン品質が N/A の場合は残り 3 軸で平均を算出する。

**判定基準**（`evaluator` エージェントの出力に従う）:

| 条件 | 判定 | 次のアクション |
|---|---|---|
| 即 NEEDS REVISION 条件（任意軸1点 / 軸2が2点以下 / DoD 未達 / Critical UI バグ）または 総合スコア < 4.0 かつ feature.loop < 3 | `NEEDS REVISION` | features.json を更新して Builder へループバック |
| 総合スコア ≥ 4.0 かつ 即 NEEDS REVISION 条件なし | `PASS` | features.json の status を `done` に更新、次 feature へ |
| feature.loop >= 3 かつ NEEDS REVISION | `BLOCKED` | status を `blocked` に更新、ユーザーへエスカレーション |

**features.json の更新（Harness が evaluator 結果を受けて更新する）**:

```json
// NEEDS REVISION 時
{
  "status": "pending",
  "loop": 2,
  "evaluator_feedback": "機能性 2/5: パスワードリセット未実装（DoD 項目あり）。技術的実行 3/5: カバレッジ 68%"
}

// PASS 時
{
  "status": "done",
  "loop": 1,
  "evaluator_feedback": null
}

// BLOCKED 時
{
  "status": "blocked",
  "loop": 3,
  "evaluator_feedback": "未解決: ..."
}
```

---

## ループ制御フロー

```
features.json を読む
  ↓
pending feature が残っている？
  ├── YES
  │     ↓
  │   builder で実装（build-cycle 経由）
  │     ↓
  │   evaluator で評価（4軸ルーブリック + Playwright）
  │     ├── PASS        → status = done → 次のループへ
  │     ├── NEEDS REVISION → status = pending, loop++, feedback 記録 → builder へ戻る
  │     └── BLOCKED     → status = blocked → ユーザーへ通知、次の feature へ
  └── NO
        ↓
      全 feature が done / blocked？
        ├── 全 done → FINAL-SUMMARY 生成して完了
        └── blocked あり → blocked 一覧をユーザーへ報告して完了
```

---

## 実行手順

### 1. セッション解決

```bash
# 既存セッション確認
ls .claude/orchestrate/ 2>/dev/null || echo "(なし)"
```

- 既存セッションがあれば再開するか新規作成するかユーザーに確認する
- 新規の場合: タスク名を確認し session-slug を決定する
  - 例: タスク名「ユーザー認証」 → `2026-05-12-user-auth`
- `SESSION_DIR=".claude/orchestrate/{session-slug}"` として以降のパスに使う

```bash
mkdir -p "$SESSION_DIR"
```

### 2. Planner フェーズ

```
planner エージェントを起動
  → {SESSION_DIR}/plan.md + {SESSION_DIR}/features.json を生成
  → ユーザー承認を得る
```

### 3. Builder → Evaluator ループ（全 pending feature が完了するまで繰り返す）

```
{SESSION_DIR}/features.json から pending feature を sequence 順に 1件選択
  ↓
builder エージェントを起動（build-cycle スキル経由で TDD 実装）
  → {SESSION_DIR}/builder-notes-{FEATURE-ID}.md を出力
  ↓
evaluator エージェントを起動（Uncorrelated、新規コンテキスト）
  → {SESSION_DIR}/evaluation-{FEATURE-ID}.md を出力
  ├── PASS         → features.json 更新（done）→ 次の feature へ
  ├── NEEDS REVISION → features.json 更新（feedback 記録）→ builder へ戻る
  └── BLOCKED      → features.json 更新（blocked）→ 次の feature へ
```

### 4. 完了

```
全 feature が done または blocked
  ↓
{SESSION_DIR}/FINAL-SUMMARY.md を生成
```

---

## FINAL-SUMMARY.md のフォーマット

```markdown
# Final Summary

**完了日時**: YYYY-MM-DD HH:MM
**完了率**: N/M features (XX%)

## 完了した機能
| ID | 名前 | ループ数 | 総合スコア |
|---|---|---|---|
| FEATURE-001 | ... | 1 | 4.3/5 |

## ブロックされた機能
| ID | 名前 | 未解決の問題 |
|---|---|---|
| FEATURE-003 | ... | ... |

## 成果物一覧
- `{SESSION_DIR}/features.json` — 機能仕様と最終ステータス
- `{SESSION_DIR}/plan.md` — 実装計画
- `{SESSION_DIR}/builder-notes-{id}.md` — 各機能の実装ノート
- `{SESSION_DIR}/evaluation-{id}.md` — 各機能の evaluator レポート
- `{SESSION_DIR}/skill-usage.json` — スキル呼び出しログ（tdd-cycle の RED/GREEN/REFACTOR 実行履歴）
```

---

## 使用例

```
/long-running Claude.ai のクローンを作りたい
```

---

## 完了条件チェックリスト

- [ ] session-slug が決定され `.claude/orchestrate/{session-slug}/` が作成された
- [ ] `{SESSION_DIR}/features.json` が生成され、ユーザーに承認された
- [ ] 全 feature の status が `done` または `blocked`
- [ ] 各 feature に `{SESSION_DIR}/evaluation-{id}.md` が存在する
- [ ] テストが全てパスしている
- [ ] コンパイルエラーがない
- [ ] `{SESSION_DIR}/FINAL-SUMMARY.md` が生成されている
- [ ] `{SESSION_DIR}/skill-usage.json` に各 feature の RED/GREEN/REFACTOR ログが記録されている

---

## 関連スキル・エージェント

- **planner** エージェント: Planner フェーズで使用。`issue-plan` スキル経由で `features.json` を生成
- **builder** エージェント: Builder フェーズで使用。`build-cycle` スキル経由で TDD 実装
- **evaluator** エージェント: Evaluator フェーズで使用。4軸ルーブリック + Playwright で定量評価
- **issue-plan**: planner エージェント内部で使用する計画スキル
- **build-cycle**: builder エージェント内部で使用する実装スキル
- **evaluate**: code-reviewer + security-reviewer の並列レビュースキル（evaluator エージェントの補完として使用可）
