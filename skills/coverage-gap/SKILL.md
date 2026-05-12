---
name: coverage-gap-analysis
user-invocable: true
description: |
  テストカバレッジのギャップを体系的に分析し、実際に動くテストコードを提案するスキル。
  以下のようなときに使う：
  - テストカバレッジを改善したい・不足テストを特定したい
  - 「テストが足りない」「カバレッジを上げたい」「どこをテストすべき」
  - 「未テストの関数」「what tests am I missing」「improve test coverage」「coverage gap」
  t-wada式TDDの原則に基づき、テストの抜け漏れを特定して優先度付きで補完する。
  引数: 分析対象ファイル・ディレクトリ（省略時はプロジェクト全体）
---

# Coverage Gap Analyzer

テストカバレッジのギャップを体系的に分析し、実際に動くテストコードを提案するスキル。
t-wada式TDDの原則（テスト作成→失敗確認→実装→パス確認）に基づき、テストの抜け漏れを特定して優先度付きで補完する。

---

## Phase 1: プロジェクト検出

まずプロジェクトの言語・テストフレームワーク・カバレッジツールを特定する。

**検出対象ファイル:**
- `pyproject.toml`, `setup.py`, `pytest.ini` → Python (pytest)
- `package.json` (jest/vitest/mocha) → TypeScript/JavaScript
- `go.mod` → Go
- `Cargo.toml` → Rust
- `Gemfile` → Ruby (rspec/minitest)

**テストディレクトリの特定:**
```
tests/, test/, __tests__/, spec/,
*_test.go, *_test.py, *.test.ts, *.spec.ts
```

引数が指定された場合は、そのファイル/ディレクトリに絞って分析する。引数の値は以降のフェーズで `SCOPE` として使用する:

```
# 引数あり例: coverage-gap src/mymodule
SCOPE = src/mymodule   # Phase 2 の --cov フラグ・Phase 3/5 の分析範囲に適用

# 引数なし
SCOPE = プロジェクト全体（pyproject.toml から自動検出またはデフォルト "src"）
```

---

## Phase 2: テスト実行とカバレッジ計測

まずテストが正常に実行できるかを確認する。失敗する場合はその原因を診断してから分析に進む。

### ステップ 2-0: テスト実行チェック（前提確認）
```bash
# Python: テストを実行して import エラーがないか確認
pytest -q 2>&1 | tail -20
```

**テストが ImportError / ModuleNotFoundError で失敗する場合（優先順位順）:**

1. **パッケージ構成がある場合** (`setup.py` / `pyproject.toml` が存在): `pip install -e .` を実行
2. **`src/` レイアウトで setup ファイルがない場合**: `tests/conftest.py` を作成して PYTHONPATH を設定する
   ```python
   # tests/conftest.py
   import sys, os
   sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))
   ```
3. **import パスの問題の場合**: `fix-imports` スキルと連携する

エラーになっているテストファイルとその原因を先にレポートしてから修正に進む。

### ステップ 2-1: カバレッジツール確認と計測

言語に応じたツールでカバレッジを計測する。ツールがなければ Phase 3 の手動分析に進む。

#### Python
```bash
# ツールの存在確認
pip show pytest-cov > /dev/null 2>&1 && echo "ok" || echo "要インストール: pip install pytest-cov"

# SCOPE の決定（Phase 1 で決定した値を使用）
# 引数あり: SOURCE_DIR=<引数のパス>（例: src/mymodule）
# 引数なし: pyproject.toml から自動検出（またはデフォルト "src"）
if [ -n "$SCOPE_ARG" ]; then
    SOURCE_DIR="$SCOPE_ARG"
else
    SOURCE_DIR=$(python -c "import tomllib; d=tomllib.load(open('pyproject.toml','rb')); print(d.get('tool',{}).get('pytest',{}).get('ini_options',{}).get('testpaths',['src'])[0])" 2>/dev/null || echo "src")
fi
pytest --cov=$SOURCE_DIR --cov-report=term-missing --cov-report=json -q 2>&1

# coverage.json から未カバー行を抽出
python -c "
import json, sys
try:
    with open('coverage.json') as f:
        data = json.load(f)
    for path, info in data.get('files', {}).items():
        pct = info['summary']['percent_covered']
        missing = info['missing_lines']
        if missing:
            print(f'{path}: {pct:.0f}% (missing: {missing})')
except FileNotFoundError:
    print('coverage.json not found - run pytest with --cov first')
"
```

#### TypeScript / JavaScript
```bash
# Jest
npx jest --coverage --coverageReporters=text-summary 2>&1

# Vitest
npx vitest run --coverage 2>&1
```

#### Go
```bash
go test ./... -coverprofile=coverage.out 2>&1
go tool cover -func=coverage.out | grep -v "100.0%"
```

#### Rust
```bash
# ツール確認
cargo tarpaulin --version > /dev/null 2>&1 || echo "要インストール: cargo install cargo-tarpaulin"
cargo tarpaulin --out Stdout 2>&1
```

---

## Phase 3: ギャップ分析

カバレッジデータと実装コードを読み合わせて、優先度付きのギャップリストを作成する。

### 優先度基準

| 優先度 | 対象 |
|--------|------|
| **Critical** | ビジネスロジック・データ変換・認証・バリデーション |
| **High** | エラーハンドリング・例外パス・境界値 |
| **Medium** | 条件分岐の各パス・オプション機能 |
| **Low** | ログ出力・設定読み込み・単純なゲッター |

### 分析の観点

カバレッジツールがない場合、以下を手動でチェックする:

1. **未テストの関数・クラス**: テストファイルに対応するテストがない実装
2. **未カバーの分岐**: `if/else`, `try/except`, `switch` で片方だけテストされているケース
3. **エッジケース**: 空文字・null/None・0・最大値・最小値
4. **非同期処理**: タイムアウト・並行処理・キャンセル
5. **外部依存**: モックなしでテストされているか、モックが実装と乖離していないか

---

## Phase 4: 既存テストパターンの学習

新しいテストは既存のパターンに合わせて書く。まずテストファイルを2〜3件読む:

```
Read: tests/ または __tests__/ の代表的なテストファイル
確認するもの:
- フィクスチャ/モックのセットアップ方法
- アサーションスタイル (assert vs expect)
- テスト名の命名規則（日本語/英語/given-when-then）
- ファイル構成とimport方法
```

---

## Phase 5: テスト提案の生成

t-wada TDDの原則に従い、既存パターンと一致する実際に動くテストコードを生成する。

### テスト命名規則
- 「○○のとき、○○になる」形式（日本語プロジェクトの場合）
- `test_should_XXX_when_YYY` 形式（英語の場合）
- 既存テストの命名規則に合わせる

### テスト構造 (Arrange / Act / Assert)
```python
def test_空のトークンを拒否する(self):
    # Arrange
    empty_token = ""

    # Act & Assert
    with pytest.raises(ValueError, match="Token cannot be empty"):
        validate_token(empty_token)
```

### 優先度別に生成する
1. Critical: 必ず提案
2. High: 必ず提案
3. Medium: 主要なものを提案
4. Low: 概要のみ記載

---

## Phase 6: レポート出力

以下のフォーマットで結果を出力する:

```
## カバレッジギャップ分析レポート

### 現在のカバレッジ
- 全体: XX%
- 言語/フレームワーク: Python / pytest-cov

### 優先度別ギャップ

#### Critical（今すぐ追加すべき）
1. `src/auth.py:validate_token()` - 認証の核心ロジックが未テスト
   
   **提案テスト** (`tests/test_auth.py` に追加):
   \```python
   def test_期限切れトークンを拒否する():
       # Arrange
       expired = create_expired_token()
       # Act & Assert
       with pytest.raises(TokenExpiredError):
           validate_token(expired)
   \```

#### High（重要なエッジケース）
2. `src/payment.py:process_payment()` - ネットワークエラー時の挙動が未カバー
   ...

### 追加後の推定カバレッジ
現在 60% → 提案テスト追加後 約 80% (推定)

### 次のアクション
1. Critical のテストを追加して失敗を確認
2. テストがパスするまで実装を修正しない（t-wada TDD原則）
3. Medium 以下は余裕があれば追加
```

---

## 注意事項

- カバレッジ100%は目標ではない。重要なビジネスロジックを優先する
- 既存テストを変更・削除せず、**追加のみ**提案する
- テスト削除でカバレッジを達成することは厳禁
- モックは必要最小限に。実際の動作に近いテストを優先する
- 提案したテストが実際にパスすることを確認してから完了とする

---

## 関連スキル

- `fix-imports` — テストのimportエラーを修正する（Phase 2-0 でエラーが出た場合に先に実行）
- `planning-tests` — TDD計画書の作成（より詳細な計画が必要な場合）
- `flaky-test-detect` — カバレッジが低い箇所はフレーキー率と相関することが多い
- `/test` — 提案テストの実行と確認
- `security-scan` — セキュリティ関連の未テストパスの発見
