# カプセル化違反の検出基準

このドキュメントは、コードベースにおけるカプセル化違反を検出し、具体的な改善提案を行うための基準を定義します。

## 目次

- [概要](#概要)
- [分析プロセス](#分析プロセスchain-of-thought)
- [評価基準](#評価基準)
  - [1. 貧血ドメインモデル](#1-貧血ドメインモデルanemic-domain-model)
  - [2. 不変性の活用](#2-不変性immutabilityの活用)
  - [3. プリミティブ型執着](#3-プリミティブ型執着primitive-obsession)
  - [4. staticメソッドの濫用](#4-staticメソッドの濫用)
  - [5. 初期化ロジックの分散](#5-初期化ロジックの分散)
  - [6. 出力引数の使用](#6-出力引数の使用)
  - [7. 多すぎる引数](#7-多すぎる引数long-parameter-list)
  - [8. デメテルの法則違反](#8-デメテルの法則違反law-of-demeter-violation)
- [適用可能な設計パターン](#適用可能な設計パターン)
- [レビュー時のチェックリスト](#レビュー時のチェックリスト)
- [出力形式](#出力形式)
- [改善による効果の対照表](#改善による効果の対照表)

---

## 概要

以下の基準に照らしてコードをレビューし、問題を特定し、具体的な改善案を提示します。

## 分析プロセス(Chain of Thought)

コード分析は以下の順序で段階的に実施します:

1. **初期調査**: クラスの責務とデータ構造を把握
2. **問題特定**: カプセル化違反のパターンを検出
3. **影響評価**: 発見した問題の深刻度と影響範囲を分析
4. **改善提案**: 具体的な設計パターンと実装例を提示
5. **効果予測**: 改善による期待効果を明確化

## 評価基準

### 1. 貧血ドメインモデル(Anemic Domain Model)

**カプセル化の原則:**

クラスが単体で正常動作するように設計する必要があります。初期設定をしなくてもはじめから使える構造にします。また、クラスが不正状態に陥らない構造を生み出さないようにし、正しく動作できるメソッドのみを外部に提供します。

**問題のあるパターン:**

- データとロジックが分離している
- publicフィールドで外部から直接変更可能
- 不正値のバリデーションが存在しない
- ビジネスロジックが欠如している

**期待される実装:**

- インスタンス変数
- 完全性を保証するようにインスタンス変数を操作するメソッド
- コンストラクタで確実に正常値を設定
- 不変性(final)による防護

<example type="bad">
<description>貧血ドメインモデル: データのみでロジックが欠如</description>
<code language="java">
import java.util.Currency;

class Money {
    int amount;
    Currency currency;
}

// 別のクラスでロジックを実装
class PaymentManager {
    static int add(int amount1, int amount2) {
        return amount1 + amount2;
    }
}
</code>
<issues>

- publicフィールドで外部から直接変更可能
- 不正値のバリデーションが存在しない
- ビジネスロジックが欠如している
- 初期化が保証されていない
- データとロジックが分離

</issues>
</example>

<example type="good">
<description>完全コンストラクタ + 値オブジェクトパターンでカプセル化</description>
<code language="java">
import java.util.Currency;

class Money {
    private final int amount;
    private final Currency currency;

    Money(final int amount, final Currency currency) {
        if (amount < 0) {
            throw new IllegalArgumentException("金額には0以上を指定してください。");
        }
        if (currency == null) {
            throw new NullPointerException("通貨単位を指定してください。");
        }
        this.amount = amount;
        this.currency = currency;
    }

    Money add(final Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("通貨単位が違います。");
        }
        final int added = amount + other.amount;
        return new Money(added, currency);
    }
}
</code>
<benefits>

- コンストラクタで不正値を防止
- final修飾子で不変性を保証
- 型安全性の確保(Money型同士の演算)
- データとロジックが同じクラスに集約
- 新しいインスタンスを返すことで不変性を維持

</benefits>
</example>

### 2. 不変性(Immutability)の活用

**問題のあるパターン:**

- 同じ変数に異なる意味の値を再代入している
- 引数を関数内で変更している
- インスタンス変数がpublicや package-privateで変更可能
- 同じインスタンスを複数箇所で共有し、予期せぬ副作用が発生

**期待される実装:**

- 各変数はfinal宣言され、一度だけ代入される
- すべての引数がfinal宣言されている
- インスタンス変数はfinalかつprivate
- 状態変更が必要な場合は新しいインスタンスを返す

<example type="bad">
<description>変数の再代入により意味が変化し、可読性が低下</description>
<code language="java">
int damage() {
    int tmp = member.power() + member.weaponAttack();
    tmp = (int)(tmp * (1f + member.speed() / 100f));
    tmp = tmp - (int)(enemy.defence / 2);
    tmp = Math.max(0, tmp);
    return tmp;
}

void addPrice(int productPrice) {
    productPrice = totalPrice + productPrice; // 引数を再利用
    if (MAX_TOTAL_PRICE < productPrice) {
        throw new IllegalArgumentException("購入金額の上限を超えています。");
    }
}
</code>
<issues>

- 変数tmpが4つの異なる意味で使用されている
- 計算の途中経過が追跡できない
- 引数の意味が途中で変化している
- デバッグが困難

</issues>
</example>

<example type="good">
<description>各ステップを独立した不変の変数で表現</description>
<code language="java">
int damage() {
    final int basicAttackPower = member.power() + member.weaponAttack();
    final int speedBoostedPower = (int)(basicAttackPower * (1f + member.speed() / 100f));
    final int damageBeforeAdjustment = speedBoostedPower - (int)(enemy.defence / 2);
    final int damage = Math.max(0, damageBeforeAdjustment);
    return damage;
}

void addPrice(final int productPrice) {
    final int increasedTotalPrice = totalPrice + productPrice;
    if (MAX_TOTAL_PRICE < increasedTotalPrice) {
        throw new IllegalArgumentException("購入金額の上限を超えています。");
    }
}
</code>
<benefits>

- 各変数が単一の責任を持つ
- 計算フローが明確
- 引数の意味が保たれる
- 変数名がビジネスロジックを文書化

</benefits>
</example>

**不変性の例外:**

パフォーマンス要件が不変性よりも優先される場合のみ可変を許容:

- 大量データの高速処理(例: リアルタイム画像処理)
- リソース制約の厳しい組み込みソフトウェア
- プロファイリングで特定されたボトルネック

可変を使用する場合は、不変条件(amount >= 0等)を必ず保証する必要があります。

### 3. プリミティブ型執着(Primitive Obsession)

**問題のあるパターン:**

- プリミティブ型(int, float, String等)を濫用している
- 同じバリデーションロジックが複数箇所に散在している
- ドメイン概念がプリミティブ型で表現されている

**期待される実装:**

- ドメイン概念ごとに値オブジェクト(Value Object)を作成
- バリデーションロジックをクラス内にカプセル化
- 型安全性を確保し、誤用を防ぐ

<example type="bad">
<description>プリミティブ型の濫用により、バリデーションが重複</description>
<code language="java">
class Common {
    int discountedPrice(int regularPrice, float discountRate) {
        if (regularPrice < 0) {
            throw new IllegalArgumentException();
        }
        if (discountRate < 0.0f) {
            throw new IllegalArgumentException();
        }
        // 計算処理...
    }
}

class Util {
    boolean isFairPrice(int regularPrice) {
        if (regularPrice < 0) {
            throw new IllegalArgumentException();
        }
        // 判定処理...
    }
}

// 型が同じなので誤用が可能
final int ticketCount = 3;
money.add(ticketCount); // チケット枚数を金額に加算できてしまう
</code>
<issues>

- 同じバリデーション(regularPrice < 0)が重複
- ドメイン知識が散在し、保守性が低い
- int型なので誤った値(負数)を渡せてしまう
- プリミティブ型では意味の異なる値を区別できない

</issues>
</example>

<example type="good">
<description>値オブジェクトでドメイン概念をカプセル化</description>
<code language="java">
/** 定価 */
class RegularPrice {
    private static final int MIN = 0;
    private final int amount;

    RegularPrice(final int amount) {
        if (amount < MIN) {
            throw new IllegalArgumentException("定価は0以上である必要があります");
        }
        this.amount = amount;
    }
}

/** 割引率 */
class DiscountRate {
    private static final float MIN = 0.0f;
    private static final float MAX = 1.0f;
    private final float rate;

    DiscountRate(final float rate) {
        if (rate < MIN || rate > MAX) {
            throw new IllegalArgumentException("割引率は0.0〜1.0の範囲である必要があります");
        }
        this.rate = rate;
    }
}

/** 割引後価格 */
class DiscountedPrice {
    private final int amount;

    DiscountedPrice(final RegularPrice regularPrice, final DiscountRate discountRate) {
        this.amount = (int)(regularPrice.amount * (1 - discountRate.rate));
    }
}

// 型安全性の確保
Money money = new Money(100, yen);
money.add(new Money(50, yen)); // OK
money.add(ticketCount); // コンパイルエラー
</code>
<benefits>

- バリデーションが各クラスに集約され、重複が解消
- 型システムで誤用を防止(負数を渡せない)
- ドメイン知識が明示的
- コンパイル時の型チェック

</benefits>
</example>

### 4. staticメソッドの濫用

**問題のあるパターン:**

- データクラスとロジッククラスが分離している
- staticメソッドでインスタンス変数を使用していない
- オブジェクト指向の原則(カプセル化)に反している

**期待される実装:**

- データとロジックを同じクラスにまとめる
- インスタンスメソッドとして実装する
- staticは横断的関心事やファクトリメソッドに限定

<example type="bad">
<description>データとロジックが分離し、貧血ドメインモデル化</description>
<code language="java">
class MoneyData {
    int amount;
}

class OrderManager {
    static int add(int moneyAmount1, int moneyAmount2) {
        return moneyAmount1 + moneyAmount2;
    }
}

moneyData1.amount = OrderManager.add(moneyData1.amount, moneyData2.amount);
</code>
<issues>

- データ(MoneyData)とロジック(OrderManager)が分離
- MoneyDataの状態を外部から直接変更
- オブジェクト指向の利点を活かせていない

</issues>
</example>

<example type="good">
<description>データとロジックをカプセル化し、staticは適切に使用</description>
<code language="java">
class Money {
    private final int amount;

    private Money(final int amount) {
        if (amount < 0) {
            throw new IllegalArgumentException("金額は0以上である必要があります");
        }
        this.amount = amount;
    }

    /** ファクトリメソッド: ゼロ円を生成 */
    static Money zero() {
        return new Money(0);
    }

    /** ファクトリメソッド: 指定金額のMoneyを生成 */
    static Money of(final int amount) {
        return new Money(amount);
    }

    /** 金額を加算する */
    Money add(final Money other) {
        return new Money(this.amount + other.amount);
    }
}

Money total = money1.add(money2);
</code>
<benefits>

- データとロジックが同じクラスに集約
- staticはファクトリメソッドに限定
- 不変オブジェクトとして実装

</benefits>
</example>

**staticメソッドを使用してよいケース:**

- ファクトリメソッド(インスタンス生成)
- 横断的関心事(ログ出力、エラー検出)
- ユーティリティメソッド(データとロジックが関係しない場合)

### 5. 初期化ロジックの分散

**問題のあるパターン:**

- コンストラクタがpublicで、初期化ロジックが散在
- 同じ初期値がコードベース全体に重複
- 初期値変更時の影響範囲が広い

**期待される実装:**

- コンストラクタをprivateにする
- ファクトリメソッドで初期化パターンを提供
- 初期値をクラス内に集約

<example type="bad">
<description>初期値がコードベースに散在し、変更の影響範囲が広い</description>
<code language="java">
class GiftPoint {
    private static final int MIN_POINT = 0;
    final int value;

    // publicコンストラクタ
    GiftPoint(final int point) {
        if (point < MIN_POINT) {
            throw new IllegalArgumentException("ポイントが0以上ではありません。");
        }
        value = point;
    }
}

// 使用箇所で具体的な値を指定(初期化ロジックが分散)
GiftPoint standardMembershipPoint = new GiftPoint(3000);
GiftPoint premiumMembershipPoint = new GiftPoint(10000);
</code>
<issues>

- 初期値(3000, 10000)がコードベースに散在
- ポイント変更時に全箇所を修正する必要がある
- 初期化パターンが不明確
- 誤った値でインスタンス化される可能性

</issues>
</example>

<example type="good">
<description>ファクトリメソッドで初期化パターンを集約</description>
<code language="java">
class GiftPoint {
    private static final int MIN_POINT = 0;
    private static final int STANDARD_MEMBERSHIP_POINT = 3000;
    private static final int PREMIUM_MEMBERSHIP_POINT = 10000;
    final int value;

    // 外部からインスタンス生成できない
    private GiftPoint(final int point) {
        if (point < MIN_POINT) {
            throw new IllegalArgumentException("ポイントが0以上ではありません。");
        }
        value = point;
    }

    /** 標準会員向け入会ギフトポイント */
    static GiftPoint forStandardMembership() {
        return new GiftPoint(STANDARD_MEMBERSHIP_POINT);
    }

    /** プレミアム会員向け入会ギフトポイント */
    static GiftPoint forPremiumMembership() {
        return new GiftPoint(PREMIUM_MEMBERSHIP_POINT);
    }
}

// 使用例: 初期化パターンが明確
GiftPoint standardPoint = GiftPoint.forStandardMembership();
GiftPoint premiumPoint = GiftPoint.forPremiumMembership();
</code>
<benefits>

- 初期値が1箇所に集約
- 初期化パターンが自己文書化
- 変更時の影響範囲が限定的
- 誤用を防止

</benefits>
</example>

**注意:** 生成ロジックが複雑化した場合は、専用のファクトリクラスを検討します。

### 6. 出力引数の使用

**問題のあるパターン:**

- 引数を戻り値として使用している
- 参照型引数の状態を変更している
- 入力と出力の区別が不明確

**期待される実装:**

- 引数は入力値として使用
- 戻り値で結果を返す
- データとロジックを同じクラスにカプセル化

<example type="bad">
<description>引数を出力として使用し、意図が不明確</description>
<code language="java">
class ActorManager {
    void shift(Location location, int shiftX, int shiftY) {
        location.x += shiftX;
        location.y += shiftY;
    }
}

// 使用例
actorManager.shift(location, 10, 20);
// locationの状態が変更されているが、明示的でない
</code>
<issues>

- 引数locationが出力として使用されている
- メソッドを読まないと引数が入力か出力か不明
- 同じロジックが重複する可能性
- 可読性が低い

</issues>
</example>

<example type="good">
<description>戻り値で結果を返し、意図を明確化</description>
<code language="java">
class Location {
    final int x;
    final int y;

    Location(final int x, final int y) {
        this.x = x;
        this.y = y;
    }

    /** 位置を移動する */
    Location shift(final int shiftX, final int shiftY) {
        final int nextX = x + shiftX;
        final int nextY = y + shiftY;
        return new Location(nextX, nextY);
    }
}

// 使用例
Location newLocation = location.shift(10, 20);
// 新しいLocationが返され、意図が明確
</code>
<benefits>

- 引数が入力、戻り値が出力と明確
- 不変オブジェクトとして実装
- コードの重複が解消
- 可読性が向上

</benefits>
</example>

### 7. 多すぎる引数(Long Parameter List)

**問題のあるパターン:**

- メソッドの引数が4個以上
- 関連するデータがバラバラに渡される
- 引数の順序を間違えやすい

**期待される実装:**

- 関連するデータをクラスにまとめる
- 引数の数を3個以下に抑える
- パラメータオブジェクトパターンを適用

<example type="bad">
<description>関連データがバラバラで、誤用しやすい</description>
<code language="java">
int recoverMagicPoint(
    int currentMagicPoint,
    int originalMaxMagicPoint,
    List<Integer> maxMagicPointIncrements,
    int recoveryAmount
) {
    int currentMaxMagicPoint = originalMaxMagicPoint;
    for (int each : maxMagicPointIncrements) {
        currentMaxMagicPoint += each;
    }
    return Math.min(currentMagicPoint + recoveryAmount, currentMaxMagicPoint);
}

// 引数の順序を間違えやすい
int recovered = recoverMagicPoint(50, 100, increments, 30);
</code>
<issues>

- 引数が4個で多すぎる
- 関連するデータ(魔法力関連)がバラバラ
- 引数の順序を間違える可能性が高い

</issues>
</example>

<example type="good">
<description>パラメータオブジェクトパターンで関連データを集約</description>
<code language="java">
class MagicPoint {
    private int currentAmount;
    private final int originalMaxAmount;
    private final List<Integer> maxIncrements;

    MagicPoint(final int currentAmount, final int originalMaxAmount) {
        this.currentAmount = currentAmount;
        this.originalMaxAmount = originalMaxAmount;
        this.maxIncrements = new ArrayList<>();
    }

    /** 魔法力の最大量 */
    int max() {
        int amount = originalMaxAmount;
        for (int each : maxIncrements) {
            amount += each;
        }
        return amount;
    }

    /** 魔法力を回復する */
    void recover(final int recoveryAmount) {
        currentAmount = Math.min(currentAmount + recoveryAmount, max());
    }
}

// 引数が1個に削減
magicPoint.recover(30);
</code>
<benefits>

- 関連するデータが1つのクラスに集約
- 引数の数が大幅に削減
- 誤用のリスクが低下
- カプセル化により状態管理が容易

</benefits>
</example>

### 8. デメテルの法則違反(Law of Demeter Violation)

**問題のあるパターン:**

- メソッドチェーン(obj.getA().getB().getC())が長い
- 内部構造への深いアクセス
- カプセル化が破れている

**期待される実装:**

- "尋ねるな、命じろ"(Tell, Don't Ask)の原則に従う
- 直接の協力者とのみやり取りする
- 処理をカプセル化する

<example type="bad">
<description>深いアクセス連鎖で内部構造が露呈</description>
<code language="java">
void equipArmor(int memberId, Equipment newArmor) {
    // 内部構造に深くアクセス
    if (party.members.get(memberId).equipments.canChange) {
        party.members.get(memberId).equipments.armor = newArmor;
    }
}
</code>
<issues>

- party.members.get().equipments.armorと3段階のアクセス
- 内部構造(membersがListであること等)が露呈
- デメテルの法則違反
- 似たコードが複数箇所に散在する可能性

</issues>
</example>

<example type="good">
<description>"尋ねるな、命じろ"に基づいてカプセル化</description>
<code language="java">
class Equipments {
    private boolean canChange;
    private Equipment head;
    private Equipment armor;
    private Equipment arm;

    /** 鎧を装備する */
    void equipArmor(final Equipment newArmor) {
        if (canChange) {
            armor = newArmor;
        }
    }

    /** 全装備を解除する */
    void deactivateAll() {
        head = Equipment.EMPTY;
        armor = Equipment.EMPTY;
        arm = Equipment.EMPTY;
    }
}

class Member {
    private final Equipments equipments;

    /** 鎧を装備する */
    void equipArmor(final Equipment newArmor) {
        equipments.equipArmor(newArmor);
    }
}

class Party {
    private final List<Member> members;

    /** メンバーに鎧を装備させる */
    void equipArmorToMember(final int memberId, final Equipment newArmor) {
        members.get(memberId).equipArmor(newArmor);
    }
}

// 使用例
party.equipArmorToMember(memberId, newArmor);
</code>
<benefits>

- 各クラスが自身の責任を持つ
- 内部構造が隠蔽されている
- デメテルの法則に準拠
- 変更に強い設計

</benefits>
</example>

## 適用可能な設計パターン

カプセル化違反を見つけた場合は、以下の設計パターンを適用します:

| 設計パターン | 適用場面 | 効果 |
|--------------|---------|------|
| 完全コンストラクタ | オブジェクト生成時 | 不正状態から防護する |
| 値オブジェクト | 値の表現 | アプリケーションで扱う値に関するロジックをカプセル化する |
| ストラテジ | アルゴリズムの切り替え | 条件分岐を削減し、ロジックを単純化する |
| ポリシー | ビジネスルールの表現 | 条件分岐を単純化したり、カスタマイズできるようにする |
| ファーストクラスコレクション | コレクションの操作 | コレクションに関するロジックをカプセル化する |
| スプラウトクラス | 機能追加 | 既存のロジックを変更せずに新機能を追加する |
| パラメータオブジェクト | 多すぎる引数 | 関連するパラメータをクラスにまとめる |

**重要**: 「値オブジェクト + 完全コンストラクタ」がカプセル化の最も基本形を体現している構造になります。

## レビュー時のチェックリスト

コードをレビューする際は、以下の順序で確認します:

1. **貧血ドメインモデルの確認**

   - [ ] データとロジックが同じクラスにあるか
   - [ ] publicフィールドが存在しないか
   - [ ] ビジネスロジックが実装されているか

2. **不変性の確認**

   - [ ] すべての変数にfinalが付いているか
   - [ ] 変数の再代入が発生していないか
   - [ ] インスタンス変数がfinalかつprivateか

3. **プリミティブ型執着の確認**

   - [ ] ドメイン概念がプリミティブ型で表現されていないか
   - [ ] 同じバリデーションが重複していないか
   - [ ] 値オブジェクトが適用されているか

4. **staticメソッドの確認**

   - [ ] データとロジックが分離していないか
   - [ ] staticの使用が適切(ファクトリ、横断的関心事)か

5. **初期化ロジックの確認**

   - [ ] コンストラクタがpublicで濫用されていないか
   - [ ] 初期値がコードベースに散在していないか
   - [ ] ファクトリメソッドが提供されているか

6. **出力引数の確認**

   - [ ] 引数が出力として使用されていないか
   - [ ] 戻り値で結果を返しているか

7. **引数の数の確認**

   - [ ] 引数が4個以上ないか
   - [ ] 関連するデータがクラスにまとめられているか

8. **デメテルの法則の確認**

   - [ ] メソッドチェーンが長くないか(2段階以内)
   - [ ] "尋ねるな、命じろ"の原則に従っているか
   - [ ] 処理が適切にカプセル化されているか

## 出力形式

レビュー結果は以下の形式で出力します:

```markdown
## レビュー結果

### 重大な問題

- [ファイル名:行番号] 問題の説明と影響範囲

### 改善推奨

- [ファイル名:行番号] 改善案と期待される効果

### 良い実装

- [ファイル名:行番号] 評価ポイント
```

思考プロセスを示すため、まず問題を特定し、次に改善案を考え、最後に具体的なコード例を提示します。

## 改善による効果の対照表

| 問題 | 改善内容 | 効果 |
|------|---------|------|
| 重複コード | 必要なロジックがクラスに集約 | 別のクラスに直接コードが書き散らされにくくなった |
| 修正漏れ | 重複コード解消 | 修正漏れも発生しにくくなった |
| 可読性低下 | ロジックがクラスに集中 | デバッグ時や仕様変更時にあちこちを見回らずに済む |
| 生焼けオブジェクト | コンストラクタで値を確定 | 未初期化状態がなくなった |
| 不正値の混入 | ガード節 + final修飾子 | 不正値が混入されないようになった |
| 思わぬ副作用 | final修飾子で不変化 | 副作用から解放された |
| 値の渡し間違い | 引数を型安全に変更 | 異なる型の値をコンパイラで防止できる |
| 初期化ロジックの分散 | ファクトリメソッド | 初期値が1箇所に集約された |
| 多すぎる引数 | パラメータオブジェクト | 引数の誤用が減少した |
| デメテルの法則違反 | カプセル化 | 内部構造が隠蔽され、変更に強くなった |
