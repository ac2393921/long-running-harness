# long-running-harness

Planner → Builder → Evaluator の3エージェントループで複雑なタスクを TDD 実装する Claude Code スキル集。

```
long-running
  └── planner  ──→ issue-plan
  └── builder  ──→ build-cycle ──→ tdd-guide ──→ tdd-cycle
                                                     ├── fix-debt
                                                     ├── flaky-test-detect
                                                     └── coverage-gap
  └── evaluator ──→ evaluate
                      ├── code-reviewer
                      ├── security-reviewer
                      ├── functionality-reviewer
                      ├── design-reviewer
                      └── originality-reviewer
```

## インストール

### Step 1: スキルをインストール（Skills CLI）

```bash
npx skills add ac2393921/long-running-harness -a claude-code
```

以下の8スキルが `~/.claude/skills/` にインストールされます:

| スキル | 役割 |
|---|---|
| `long-running` | メインオーケストレーター |
| `issue-plan` | 計画フェーズ・features.json 生成 |
| `build-cycle` | 実装フェーズ・TDD ループ管理 |
| `tdd-cycle` | RED→GREEN→REFACTOR サイクル |
| `evaluate` | 4軸ルーブリック評価 |
| `fix-debt` | 技術的負債の自動検出・修正 |
| `flaky-test-detect` | フレーキーテスト検出・修正 |
| `coverage-gap` | カバレッジギャップ分析・三角測量 |

### Step 2: エージェントをインストール

```bash
git clone https://github.com/ac2393921/long-running-harness.git
cd long-running-harness
./install-agents.sh
```

以下の9エージェントが `~/.config/agents/agents/` にインストールされます:

`planner`, `builder`, `evaluator`, `tdd-guide`, `code-reviewer`, `security-reviewer`, `functionality-reviewer`, `design-reviewer`, `originality-reviewer`

## 使い方

Claude Code で `/long-running` と入力するだけ。

```
/long-running ユーザー認証機能を実装して
```

### フロー

```mermaid
flowchart TD
    Start([タスク開始]) --> Planner

    Planner["🗂 Planner\nissue-plan スキル\nfeatures.json 生成"]
    Planner --> Approve{ユーザー承認}
    Approve -->|承認| Builder

    Builder["🔨 Builder\nbuild-cycle → tdd-guide\nRED → GREEN → REFACTOR"]
    Builder --> Evaluator

    Evaluator["🔍 Evaluator\nevaluate スキル\n4軸ルーブリック評価"]
    Evaluator --> Judge{判定}

    Judge -->|PASS\nスコア ≥ 4.0| Done[status: done]
    Judge -->|NEEDS REVISION\nloop < 3| Builder
    Judge -->|BLOCKED\nloop ≥ 3| Blocked[status: blocked\nユーザーへ通知]

    Done --> Next{pending feature\n残あり?}
    Blocked --> Next
    Next -->|YES| Builder
    Next -->|NO| Summary([FINAL-SUMMARY 生成])
```

## skill-usage.json

各 `tdd-cycle` フェーズの実行ログが `.claude/orchestrate/{session}/skill-usage.json` に記録されます。
TDD が実際に実行されたか監査できます。

```json
{
  "version": "1.0",
  "invocations": [
    { "skill": "tdd-cycle", "phase": "RED",      "result": "FAIL" },
    { "skill": "tdd-cycle", "phase": "GREEN",    "result": "PASS" },
    { "skill": "tdd-cycle", "phase": "REFACTOR", "result": "PASS" }
  ]
}
```
