---
name: evaluate
description: Uncorrelated Evaluator — 4軸ルーブリック専門エージェント（functionality-reviewer・code-reviewer・design-reviewer・originality-reviewer）と security-reviewer を5並列実行し、成果物を多面的に独立評価します。PASS / NEEDS WORK / BLOCKED 判定を返します。Self-leniency 防止のため、実装エージェントのコンテキストを引き継がない新規エージェントとして起動します。「レビューして」「評価して」「実装を確認して」などのリクエストで起動します。
user-invocable: true
---

# Uncorrelated Evaluator

実装後のコードを4軸ルーブリック専門エージェント + セキュリティレビュアーで**5並列評価**します。

> ⚠️ **Self-leniency 防止**: このスキルは常に新規エージェントとして起動します。
> 実装エージェントのコンテキストを**引き継がない**ことが必須です。

---

## エージェントと担当軸の対応

| エージェント | 担当軸 | スコア |
|--|--|--|
| `functionality-reviewer` | 機能性（DoD チェック + Playwright フロー） | 1-5 |
| `code-reviewer` | 技術的実行（テスト・SRP/DRY・パフォーマンス） | 1-5 |
| `design-reviewer` | デザイン品質（Playwright スクリーンショット・WCAG） | 1-5 / N/A |
| `originality-reviewer` | 独創性（洗練度・工夫・ボイラープレート率） | 1-5 |
| `security-reviewer` | セキュリティ（OWASP・インジェクション・シークレット漏洩） | PASS / BLOCKED |

---

## 入力

- **変更ファイルパス**（必須）: 引数で指定。未指定の場合は `git diff --name-only HEAD` で自動検出
- **実装ノート**（任意）: `implementation-notes.md` などのハンドオフドキュメントのパス
- **plan.md パス**（任意）: DoD が記載された計画書。デフォルト `plan.md`
- **ライブURL**（任意）: Playwright 検証対象の開発サーバー URL
- **出力ディレクトリ**（任意）: デフォルト `.claude/orchestrate/`
- **ループカウンタ**（任意）: デフォルト `1`
- **最大ループ数**（任意）: デフォルト `3`

---

## 実行手順

### Step 1: 対象コードの特定

```bash
# 引数未指定の場合
git diff --name-only HEAD
```

変更ファイルが存在しない場合は「評価対象が見つかりません」とユーザーに伝えて終了する。

---

### Step 2: 5エージェント並列実行

全エージェントに以下を渡し、**同時に起動**する:

```
並列実行:
  ├── functionality-reviewer
  │     入力: 変更ファイルの内容 + plan.md（DoD） + ライブURL（あれば）
  │     指示: DoD チェックと Playwright フロー確認で機能性を 1-5 スコアで評価せよ
  │     出力: functionality-review.md
  │
  ├── code-reviewer
  │     入力: 変更ファイルの内容 + 実装ノート（あれば）
  │     指示: テスト・SRP/DRY・パフォーマンスを確認し Critical/Warning/Info と
  │           技術的実行スコア（1-5）を報告せよ
  │     出力: review-comments.md
  │
  ├── design-reviewer
  │     入力: ライブURL（あれば）
  │     指示: 3ブレークポイントでスクリーンショット取得し UI 品質を 1-5 で評価せよ。
  │           フロントエンドなし時は N/A を返せ
  │     出力: design-review.md
  │
  ├── originality-reviewer
  │     入力: 変更ファイルの内容
  │     指示: 洗練度・工夫・ボイラープレート率を確認し独創性を 1-5 で評価せよ
  │     出力: originality-review.md
  │
  └── security-reviewer
        入力: 変更ファイルの内容 + 実装ノート（あれば）
        指示: OWASP Top 10・インジェクション・シークレット漏洩・認証認可を確認し
              Critical / Warning / Info の3段階で報告せよ
        出力: security-review.md
```

---

### Step 3: 判定

5エージェントの結果を収集し、以下の優先順位で判定する:

| 条件 | 判定 |
|---|---|
| security-reviewer で Critical 1件以上 | `BLOCKED` |
| loop >= max_loops かつ未解決問題あり | `BLOCKED` |
| functionality-reviewer で DoD 未達成 1件以上 | `NEEDS WORK` |
| いずれかの軸スコア（N/A 除く）< 3 | `NEEDS WORK` |
| 全軸平均（N/A 除く）< 4.0 かつ loop < max_loops | `NEEDS WORK` |
| すべての条件をクリア | `PASS` |

---

### Step 4: 結果の保存

出力ディレクトリへ保存する。feature ID が指定されている場合:

- `eval-{feat-id}.md` — 統合サマリー（long-running から呼び出す場合）
- 各 `*-review.md` — スタンドアロンで呼び出す場合

---

## 出力フォーマット（統合サマリー）

```markdown
# Evaluation Summary

**Verdict**: PASS / NEEDS WORK / BLOCKED (Loop: N/M)

| 軸 | エージェント | スコア | 判定 |
|--|--|--|--|
| 機能性 | functionality-reviewer | N/5 | ✓/⚠️ |
| 技術的実行 | code-reviewer | N/5 | ✓/⚠️ |
| デザイン品質 | design-reviewer | N/5 or N/A | ✓/⚠️/- |
| 独創性 | originality-reviewer | N/5 | ✓/⚠️ |
| セキュリティ | security-reviewer | PASS/BLOCKED | ✓/🚫 |

**総合スコア（N/A 除く）: N.N/5**

---

## 機能性レビュー（functionality-reviewer）
[functionality-review.md の内容サマリー]

## 技術的実行レビュー（code-reviewer）
[review-comments.md の内容サマリー]

## デザイン品質レビュー（design-reviewer）
[design-review.md の内容サマリー]

## 独創性レビュー（originality-reviewer）
[originality-review.md の内容サマリー]

## セキュリティレビュー（security-reviewer）
[security-review.md の内容サマリー]

---

## 次のアクション
[NEEDS WORK / BLOCKED の場合のみ、優先順で列挙]
```

---

## 完了条件

- [ ] 5エージェントすべてが結果を返した
- [ ] 判定（PASS / NEEDS WORK / BLOCKED）を呼び出し元へ返した
- [ ] 全レビューファイルが出力ディレクトリに保存された

---

## 関連スキル

- **long-running**: Evaluator フェーズでこのスキルを使用
- **fix-debt**: 副作用チェックでこのスキルを使用
- **tdd-cycle**: 実装完了後の品質ゲートとしてこのスキルを使用
