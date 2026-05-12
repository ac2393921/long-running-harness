---
name: issue-plan
description: 任意のタスク（GitHub Issue・自由記述リクエスト・口頭要件）を起点に、受け入れ条件確認・スコープ定義・影響分析・テスト戦略を含む実装計画（15セクション）と、builder エージェントへ渡す features.json を生成します。「〇〇を作って」「実装計画を作って」「Issue #123 の計画」などのリクエストで起動します。
---

# タスク実装計画

任意の入力（GitHub Issue・自由記述リクエスト・口頭要件）を起点に、受け入れ条件の確認・スコープ定義・影響分析・テスト戦略を含む実装計画を作成します。

---

## コアワークフロー

### Step 1: タスク情報の収集と正規化

入力の種類に応じて情報を収集する：

- **GitHub Issue URL / 番号**（例: `#123`, `https://github.com/org/repo/issues/123`）
  → gh CLI または WebFetch でタイトル・本文・ラベルを取得する
- **自由記述リクエスト**（例:「Claude.ai のクローンを作って」）
  → そのまま Task Title として扱い、AskUserQuestion で追加情報を収集する
- **引数なし / 不明**
  → AskUserQuestion で「何を作りたいか」を確認する

収集すべき情報：
- タスク名・概要
- 背景・目的（Why が不明なら必ず確認）
- 技術スタック（既存プロジェクトがあればコードベース調査で判断）
- 優先度（任意）

### Step 2: コードベース調査

Grep/Glob/Read で関連ファイル・既存パターン・影響範囲を調査する。

### Step 3: テンプレートを埋める

以下の15セクションテンプレートを順に埋める。曖昧な点は「1. AC確認」の質問リストに追記する。

### Step 4: features.json を生成する

実装計画（セクション4の実装方針）が固まったら、各ステップを1機能単位に分解して `features.json` を生成する。
このファイルが builder エージェントへの唯一の入力となる。

**出力ルール（重要）**: `features.json` はチャット内にインライン出力すること。ファイルへの保存はユーザー承認後にユーザーが行う。エージェントは planning フェーズ中に disk へ保存しない。

生成ルール：
- 1 feature = builder が1回のセッションで実装できる最小単位
- `tests` には「最初は失敗するテスト」を具体的に列挙する（TDD: Red → Green）
- `dependencies` には先行 feature の `id` を列挙する
- `status` は常に `"pending"` で初期化する

### Step 5: ユーザーへ確認

「13. 確認事項」の未決定項目をユーザーに提示し、回答を得る。

### Step 6: 承認待ち

すべての確認事項が解消され、ユーザーが承認するまで実装に進まない。

---

## 出力テンプレート

```markdown
# タスク実装計画

## タスク情報

**タスクID**: [#XXX（GitHub Issue の場合）/ なし]
**タイトル**: [タスクのタイトル・リクエスト概要]
**入力形式**: [GitHub Issue / 自由記述 / 口頭リクエスト]
**優先度**: [High / Medium / Low / 未設定]
**背景・目的**: [なぜこのタスクが必要か]

---

## 1. Acceptance Criteria（受け入れ条件）の確認

### 明記されている条件
- [ ] 条件1
- [ ] 条件2

### 曖昧な点・確認が必要な項目
- [ ] 質問1
- [ ] 質問2

---

## 2. スコープ定義

### 対象（In Scope）
- 機能A
- 機能B

### 対象外（Out of Scope）
- 機能X（別Issue）

---

## 3. 調査結果

### 関連ファイル・モジュール
- `path/to/file1.ts` — [役割]
- `path/to/file2.ts` — [役割]

### 既存パターン・参考実装
- パターン1：[説明 + ファイルパス]

### 影響範囲
- **DB**: [スキーマ変更有無]
- **API**: [契約変更有無・後方互換性]
- **他システム**: [連携有無]
- **ドキュメント**: [更新対象]

---

## 4. 実装方針

### Phase 1: [フェーズ名]
1. [ステップ1] — `path/to/file1.ts`
   - 変更内容: [詳細]
   - 依存: なし

2. [ステップ2] — `path/to/file2.ts`
   - 変更内容: [詳細]
   - 依存: ステップ1

### Phase 2: [フェーズ名]
1. [ステップ3] — [詳細]

### 影響ファイル一覧

| ファイル | 変更内容 | 影響度 | 後方互換性 |
|--------|---------|------|---------|
| path/to/file1.ts | 新規メソッド | Medium | 互換 |
| path/to/file2.ts | 既存関数修正 | High | 要確認 |

---

## 5. DBスキーマ変更

- [ ] 変更なし
- [ ] 変更あり → 内容:

```sql
-- Migration内容
ALTER TABLE ...
```

### マイグレーション戦略
- **方針**: [Rolling / Blue-Green / 他]
- **ロールバック計画**: [方法・所要時間]

---

## 6. API契約・後方互換性

### 新規API / 変更API
```
GET /api/v1/endpoint
Request: {...}
Response: {...}
```

### 後方互換性
- [ ] 互換変更のみ
- [ ] 非互換変更あり → 移行戦略: [内容]

---

## 7. セキュリティ・パフォーマンス考慮

### セキュリティ
- [ ] SQLインジェクション対策: [内容]
- [ ] 認証・認可の確認: [内容]
- [ ] 入力値バリデーション: [内容]

### パフォーマンス
- [ ] N+1クエリの可能性: [評価]
- [ ] インデックス戦略: [内容]

---

## 8. テスト戦略（t-wada式TDD 3層）

### Unit Tests（単体テスト）
- **対象**: ビジネスロジック・ユーティリティ
- **テストケース**:
  - `test_XXX_returns_Y_when_given_Z()`
  - `test_edge_case_XXX()`
- **参照パターン**: [既存テストファイルパス]

### Integration Tests（統合テスト）
- **対象**: APIエンドポイント・DB操作・モジュール間連携
- **テストケース**:
  - `test_POST_creates_record_and_returns_201()`
  - `test_validation_returns_400_for_invalid_input()`
- **参照パターン**: [既存テストファイルパス]

### E2E Tests（エンドツーエンドテスト）
- **対象**: ユーザーフロー・主要シナリオ（該当する場合）
- **テストケース**:
  - `test_user_can_complete_full_flow()`
- **参照パターン**: [既存テストファイルパス]

---

## 9. ドキュメント更新の必要性

- [ ] 更新不要
- [ ] 更新が必要 → 対象: [ファイルパス]
- [ ] ADR（Architecture Decision Record）作成が必要

---

## 10. デプロイ考慮事項

### デプロイ方式
- [ ] 通常デプロイ
- [ ] 段階的ロールアウト（方式: [Blue-Green / Canary / Feature Flag]）

### ロールバック計画
- **トリガー**: [問題発生時の判定基準]
- **手順**: [ロールバック方法]
- **所要時間**: [XX分]

### 本番検証項目
- [ ] ログ・アラート確認
- [ ] 監視メトリクス確認
- [ ] ユーザー影響確認

---

## 11. Definition of Done（完了の定義）

- [ ] すべてのAcceptance Criteriaを満たしている
- [ ] Unitテスト カバレッジ >= XX%
- [ ] Integrationテスト がすべてパス
- [ ] E2Eテスト がすべてパス（該当する場合）
- [ ] コードレビュー 合格
- [ ] セキュリティレビュー 合格
- [ ] ドキュメント 更新済み
- [ ] 本番環境での検証 完了

---

## 12. リスク・注意点

- **リスク1**: [説明]
  - 影響度: [High/Medium/Low]
  - 対策: [内容]

- **リスク2**: [説明]
  - 影響度: [High/Medium/Low]
  - 対策: [内容]

---

## 13. 確認事項・未決定項目

実装前にユーザーへの確認が必要：

- [ ] [確認項目1]: [オプションA / オプションB]
- [ ] [確認項目2]: スケジュール・優先度
- [ ] [確認項目3]: 他チームとの依存関係

---

## 14. タイムライン推定

| フェーズ | 推定時間 | 根拠 |
|--------|--------|-----|
| Phase 1: コア実装 | Xh | [根拠] |
| Phase 2: 統合・検証 | Yh | [根拠] |
| Phase 3: レビュー・修正 | Zh | [根拠] |
| **合計** | **XXh** | |

---

## 15. 機能仕様（features.json）

planner-builder 分離のための外部アーティファクト。
builder エージェントはこの JSON を読み込み、`status: "pending"` の feature を1件ずつ実装する。

```json
{
  "task": {
    "id": "#XXX",
    "title": "[タスクのタイトル]",
    "source": "github_issue | free_form | other",
    "priority": "High | Medium | Low | unknown"
  },
  "meta": {
    "created_at": "YYYY-MM-DD",
    "total_estimated_hours": 0
  },
  "features": [
    {
      "id": "feat-001",
      "title": "[短い機能名]",
      "description": "[この feature が実装する内容の1〜2行説明]",
      "phase": 1,
      "acceptance_criteria": [
        "[この feature が満たす AC の番号または文章]"
      ],
      "files": {
        "create": ["path/to/new_file.ts"],
        "modify": ["path/to/existing_file.ts"]
      },
      "tests": {
        "unit": [
          {
            "name": "test_[function]_returns_[expected]_when_[condition]",
            "description": "[テストが検証すること]",
            "file": "tests/unit/test_xxx.py"
          }
        ],
        "integration": [
          {
            "name": "test_[endpoint]_[action]_returns_[status]",
            "description": "[テストが検証すること]",
            "file": "tests/integration/test_xxx.py"
          }
        ],
        "e2e": []
      },
      "dependencies": [],
      "risk": "Low | Medium | High",
      "estimated_hours": 0,
      "status": "pending"
    },
    {
      "id": "feat-002",
      "title": "[短い機能名]",
      "description": "[説明]",
      "phase": 1,
      "acceptance_criteria": ["[AC]"],
      "files": {
        "create": [],
        "modify": ["path/to/file.ts"]
      },
      "tests": {
        "unit": [],
        "integration": [
          {
            "name": "test_[name]",
            "description": "[説明]",
            "file": "tests/integration/test_yyy.py"
          }
        ],
        "e2e": []
      },
      "dependencies": ["feat-001"],
      "risk": "Medium",
      "estimated_hours": 0,
      "status": "pending"
    }
  ]
}
```

**フィールド説明**

| フィールド | 説明 |
|-----------|------|
| `id` | 連番ID。`feat-001` 形式 |
| `title` | builder が1セッションで実装する機能の名前 |
| `description` | 何をするかの説明（実装者が読む） |
| `phase` | 実装フェーズ番号（セクション4と対応） |
| `acceptance_criteria` | この feature が満たす AC の一覧 |
| `files.create` | 新規作成するファイルパス |
| `files.modify` | 変更するファイルパス |
| `tests.unit` | 単体テスト（最初は失敗、builder が Green にする） |
| `tests.integration` | 統合テスト（同上） |
| `tests.e2e` | E2Eテスト（同上） |
| `dependencies` | 先に完了が必要な feature の `id` 一覧 |
| `risk` | リスク評価 |
| `estimated_hours` | 工数見積もり（時間） |
| `status` | `pending` / `in_progress` / `done` — builder が更新する |

---

## 次のステップ

1. **確認フェーズ**: 「## 13. 確認事項」にユーザーが回答
2. **承認フェーズ**: 実装計画全体を承認
3. **features.json 保存**: プロジェクトルートに `features.json` として保存
4. **実装フェーズ**: builder エージェントが `features.json` を読み、`status: "pending"` の feature を順次実装

**承認されるまで実装に進まないこと。**
```

---

## 品質チェックリスト

スキル完了前の最終確認：

- [ ] 15セクションがすべて埋まっている
- [ ] `features.json` が生成されている
- [ ] 全 feature に `tests`（最初は失敗するテスト）が列挙されている
- [ ] 「13. 確認事項」の未決定項目にユーザーが回答済み
- [ ] ユーザーの承認を得ている

## 関連スキル

- **long-running**: features.json を入力として Planner→Builder→Evaluator ループで実装まで完走する（このスキルの後続）
- **tdd-cycle**: features.json の各 feature を単体で TDD 実装するフェーズ
- **planning-tests**: より詳細なテスト計画書（TEST_PLAN.md）を生成する場合
- **analyzing-requirements**: 大規模要件から DESIGN.md を先に生成する場合
