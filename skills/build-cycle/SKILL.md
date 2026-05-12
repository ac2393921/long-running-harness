---
name: build-cycle
description: |
  features.json を読み込み、pending な機能を1件ずつ tdd-guide エージェント（内部で tdd-cycle を使用）で実装するスキル。
  Context anxiety（トークン上限接近による焦り）と Context rot（情報劣化）を防ぐため、
  機能単位のループ・状態管理・implementation-notes.md への記録を担う。
  builder エージェントが実装フェーズを開始するときは必ずこのスキルを呼ぶ。
---

# build-cycle スキル

## 哲学

**1機能 = 1サイクル。完了を急がない。**

Context anxiety の根本は「未完了なのに完了と言いたくなる焦り」。
このスキルは機能を小さな単位に分割し、各機能の完了を数値で示すことで焦りを排除する。
「全て完了しました」は禁止。「feat-N/M 完了」だけが許可された完了報告。

---

## サイクル

```
LOAD → PICK → TDD → RECORD → CHECK → NEXT
  ↑__________________________________|
```

---

## Phase 1: LOAD（features.json の読み込み）

### ステップ

1. **features.json を Read する**

   ```
   Read("features.json")
   ```

   - ファイルが存在しない場合: ユーザーへ「`issue-plan` スキルで features.json を生成してください」と報告し、スキルを終了する。

2. **implementation-notes.md を確認する**

   ```
   Read("implementation-notes.md")  // 存在する場合のみ
   ```

   - 存在する場合: どの feat-XXX まで完了済みか把握する
   - 存在しない場合: 全 feature が未実装と見なす

3. **未実装 feature を特定する**

   - `status: "pending"` の feature を `phase` → 依存関係の順に並べる
   - `dependencies` に含まれる feat の `status` がすべて `"done"` でない feature はスキップする
   - **フィルタ後に実装可能な feature が 0 件の場合**: ユーザーへ「すべての pending feature の dependencies が未解決です（循環依存の可能性）。`features.json` の dependencies を見直してください」と報告し、スキルを終了する

4. **skill-usage.json を初期化する**（存在しない場合のみ）

   `.claude/orchestrate/skill-usage.json` が存在するか確認する。
   存在しない場合、以下の内容で Write する:
   ```json
   {
     "version": "1.0",
     "created_at": "[ISO8601]",
     "updated_at": "[ISO8601]",
     "invocations": []
   }
   ```

5. **LOAD 完了を報告する**

   ```
   [build-cycle] LOAD 完了
   合計: N 機能 | 完了: X 機能 | 残り: Y 機能
   次の実装対象: feat-XXX「機能名」
   ```

---

## Phase 2: PICK（次の機能を選択）

### ステップ

1. **最初の `status: "pending"` かつ dependencies が満たされた feature を選択する**

2. **features.json の該当 feature の status を `"in_progress"` に更新する**

   ```json
   { "status": "in_progress" }
   ```

3. **PICK 完了を報告する**

   ```
   [build-cycle] feat-XXX「機能名」を開始します
   acceptance_criteria: N 件
   tests.unit: N 件 / tests.integration: N 件
   dependencies: [feat-YYY（完了済み）]
   ```

---

## Phase 3: TDD（tdd-guide エージェントで実装）

### ステップ

1. **tdd-guide エージェントを起動する**

   feature の情報をプロンプトに渡す:

   ```
   Agent({
     subagent_type: "tdd-guide",
     prompt: `
   feat-XXX: [feature.title]

   ## 実装対象ファイル
   新規作成: [feature.files.create]
   変更: [feature.files.modify]

   ## 受け入れ条件
   [feature.acceptance_criteria の各項目を箇条書き]

   ## テスト戦略
   ### Unit Tests
   [feature.tests.unit の各テスト名・説明]

   ### Integration Tests
   [feature.tests.integration の各テスト名・説明]

   ### E2E Tests
   [feature.tests.e2e の各テスト名・説明（空の場合は省略）]
     `
   })
   ```

2. **tdd-guide の完了を待つ**

   tdd-guide（内部で tdd-cycle を使用）が `🔵 REFACTOR完了` を報告するまで待機する。
   tdd-guide がエラーを報告した場合: そのエラー内容を記録してユーザーへ報告し、このスキルを一時停止する。

---

## Phase 4: RECORD（実装結果を記録）

### ステップ

1. **features.json の該当 feature の status を `"done"` に更新する**

   ```json
   { "status": "done" }
   ```

2. **implementation-notes.md に記録を追記（append）する**

   ```markdown
   ## feat-XXX: [feature.title]

   - **実装日時:** YYYY-MM-DD
   - **実装ファイル:**
     - 新規: [feature.files.create]
     - 変更: [feature.files.modify]
   - **テスト結果:** N 件 PASS
   - **acceptance_criteria:**
     - [x] 条件1
     - [x] 条件2
   - **次の機能:** feat-YYY（または「なし（最終機能）」）
   ```

3. **RECORD 完了を報告する**

   ```
   [build-cycle] feat-XXX「機能名」実装完了
   進捗: X/N 機能完了
   implementation-notes.md を更新しました
   ```

---

## Phase 5: CHECK（コンテキスト確認）

### ステップ

1. **features.json の `context_checkpoints` を確認する**

   現在完了した feat-XXX が checkpoints に登録されているか確認する。
   登録されている場合: checkpoint に定義された `save_artifacts` が最新か確認する。

2. **コンテキスト長の主観的評価**

   応答が長くなってきたと感じる場合、または処理した機能数が多い場合は以下を実行する:
   - implementation-notes.md が最新状態であることを確認する（Phase 4 で完了済みのはず）
   - ユーザーへ「コンテキストが長くなっています。/compact を推奨します」と報告する

3. **CHECK 完了**（問題なければ次フェーズへ）

---

## Phase 6: NEXT（次の機能へ）

### ステップ

1. **残りの `status: "pending"` feature を確認する**

   - 残りあり: **Phase 2（PICK）に戻る**
   - 残りなし: 完了報告へ

2. **全機能完了の報告**

   ```
   [build-cycle] 全 N 機能の実装が完了しました
   完了: N/N 機能
   implementation-notes.md に全記録を保存済み
   次のステップ: orchestrator に報告し、Review フェーズへ進んでください
   ```

---

## Context Anxiety 防止ルール

### 禁止表現

- ❌ 「実装が完了しました」（全体の完了宣言）
- ❌ 「全ての機能を実装しました」
- ❌ 「作業が終わりました」

### 許可表現

- ✅ 「feat-001 実装完了。残り X 機能。次: feat-002」
- ✅ 「feat-N/M 実装済み。implementation-notes.md を更新しました」
- ✅ 「[build-cycle] 全 N 機能の実装が完了しました」（全機能完了時のみ）

### tdd-progress.md との連携

tdd-cycle スキルがコンテキスト圧縮前に `tdd-progress.md` を書き出した場合:
- そのファイルを Read して中断状態を把握し、続きの実装を再開する

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| features.json が存在しない | ユーザーへ `issue-plan` スキル実行を依頼し、スキル終了 |
| dependencies 未完了の feature のみ残っている | ユーザーへ報告（循環依存の可能性） |
| tdd-cycle がエラーを報告 | エラー内容を記録して一時停止。ユーザーへ報告 |
| テストが5回試行後もパスしない | ユーザーへ報告し、手動対応を求める |

---

## 関連スキル

- **tdd-guide**: このスキルから呼ばれるエージェント。tdd-cycle スキルを内部で使用し、1機能の RED→GREEN→REFACTOR サイクルを実行する
- **issue-plan**: このスキルの前段。features.json を生成する
- **coverage-gap**: tdd-cycle 内の三角測量で使用される
