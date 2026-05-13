# 関心の分離の検出基準 - 追加パターン

## 目次

- [パターン 4: ロジックの不適切な共有](#パターン-4-ロジックの不適切な共有)
- [パターン 5: 継承による関心の混在](#パターン-5-継承による関心の混在)

---

## 補足: その他の関心の分離パターン

### パターン 4: ロジックの不適切な共有

**症状:** 異なる目的のロジックが同じ static メソッドやユーティリティクラスで共有され、一方の変更が他方に意図しない影響を与える

<example type="bad">
<description>
通常割引とサマー割引が同じstaticメソッド `getDiscountPrice()` を共有している。通常割引の割引額を変更すると、サマー割引にも影響してしまう。
</description>

<code language="java">
class DiscountManager {
    List<Product> discountProducts;
    int totalPrice;

    /**
     * 割引価格を取得する
     * @param price 商品価格
     * @return 割引価格
     */
    static int getDiscountPrice(int price) {
        int discountPrice = price - 300;
        if (discountPrice < 0) {
            discountPrice = 0;
        }
        return discountPrice;
    }

}

class SummerDiscountManager {
DiscountManager discountManager;

    boolean add(Product product) {
        if (product.id < 0) {
            throw new IllegalArgumentException();
        }
        if (product.name.isEmpty()) {
            throw new IllegalArgumentException();
        }

        int tmp;
        if (product.canDiscount) {
            // 通常割引のロジックを流用している
            tmp = discountManager.totalPrice + DiscountManager.getDiscountPrice(product.price);
        } else {
            tmp = discountManager.totalPrice + product.price;
        }
        if (tmp <= 30000) {
            discountManager.totalPrice = tmp;
            discountManager.discountProducts.add(product);
            return true;
        } else {
            return false;
        }
    }

}
</code>

<issues>
- **意図しない結合**: 通常割引の変更がサマー割引に波及する
- **単一責任の原則違反**: 1つのメソッドが複数の割引タイプの責任を持つ
- **変更の影響範囲が不明確**: 割引額変更時に影響を受ける範囲が予測困難
- **テスタビリティの低下**: 異なる割引タイプを独立してテストできない
- **ビジネスルールの混在**: 異なるビジネスコンテキストのルールが同じコードで表現される
- **保守性の低下**: 将来的に割引ルールが分岐したときに対応困難
</issues>
</example>

<example type="good">
<description>
各割引タイプごとに独立したクラスを作成し、それぞれが独自の割引ロジックを持つ。Value Objectパターンを適用し、割引額の変更が他の割引タイプに影響しない設計にする。
</description>

<code language="java">
// 定価クラス
class RegularPrice {
    private static final int MIN_AMOUNT = 0;
    final int amount;

    RegularPrice(final int amount) {
        if (amount < MIN_AMOUNT) {
            throw new IllegalArgumentException("価格は0以上である必要があります。");
        }
        this.amount = amount;
    }

}

// 通常割引価格クラス
class RegularDiscountedPrice {
private static final int MIN_AMOUNT = 0;
private static final int DISCOUNT_AMOUNT = 300;
final int amount;

    RegularDiscountedPrice(final RegularPrice price) {
        if (price == null) {
            throw new NullPointerException("定価は必須です。");
        }
        int discountedAmount = price.amount - DISCOUNT_AMOUNT;
        if (discountedAmount < MIN_AMOUNT) {
            discountedAmount = MIN_AMOUNT;
        }
        amount = discountedAmount;
    }

}

// 夏季割引価格クラス
class SummerDiscountedPrice {
private static final int MIN_AMOUNT = 0;
private static final int DISCOUNT_AMOUNT = 500;
final int amount;

    SummerDiscountedPrice(final RegularPrice price) {
        if (price == null) {
            throw new NullPointerException("定価は必須です。");
        }
        int discountedAmount = price.amount - DISCOUNT_AMOUNT;
        if (discountedAmount < MIN_AMOUNT) {
            discountedAmount = MIN_AMOUNT;
        }
        amount = discountedAmount;
    }

}
</code>

<benefits>
- **独立した責任**: 各割引タイプが独自の割引ロジックを持つ
- **変更の局所化**: 通常割引の変更がサマー割引に影響しない
- **ビジネスルールの明確化**: 各クラスが特定のビジネスコンテキストを表現
- **テスタビリティ向上**: 各割引タイプを独立してテスト可能
- **拡張性向上**: 新しい割引タイプ（例：冬季割引）を追加しても既存コードに影響なし
- **保守性向上**: 各割引の仕様変更が容易
</benefits>
</example>

**重要な原則:**
同じようなロジック、似ているロジックであっても、**目的が違うロジックは共通化してはいけない**。表面的な類似性ではなく、ビジネス上の意味と変更理由で分離を判断する。

---

### パターン 5: 継承による関心の混在

**症状:** サブクラスがスーパークラスの実装詳細に強く依存し、スーパークラスの変更がサブクラスに波及する

<example type="bad">
<description>
FighterPhysicalAttackクラスがPhysicalAttackクラスを継承し、スーパークラスのメソッドをオーバーライドしている。スーパークラスの実装変更がサブクラスに影響する。
</description>

<code language="java">
class PhysicalAttack {
    // 単体攻撃のダメージ値を返す
    int singleAttackDamage() {
        // 基本ダメージ計算
        return 50;
    }

    // 2回攻撃のダメージ値を返す
    int doubleAttackDamage() {
        // 基本2回攻撃ダメージ計算
        return 80;
    }

}

class FighterPhysicalAttack extends PhysicalAttack {
@Override
int singleAttackDamage() {
// スーパークラスのメソッドに依存
return super.singleAttackDamage() + 20;
}

    @Override
    int doubleAttackDamage() {
        // スーパークラスのメソッドに依存
        return super.doubleAttackDamage() + 20;
    }

}
</code>

<issues>
- **強い結合**: サブクラスがスーパークラスの実装に強く依存
- **脆い基底クラス問題**: スーパークラスの変更がサブクラスを破壊する可能性
- **カプセル化の破壊**: サブクラスがスーパークラスの内部実装を知る必要がある
- **テスタビリティの低下**: スーパークラスなしではサブクラスをテストできない
- **変更の波及**: PhysicalAttackの変更がFighterPhysicalAttackに影響
- **継承の誤用**: IS-A関係ではなくHAS-A関係が適切
</issues>
</example>

<example type="good">
<description>
継承より委譲（Composition over Inheritance）の原則を適用。コンポジション構造にすることで、PhysicalAttackの変更から独立する。
</description>

<code language="java">
// 物理攻撃インターフェース
interface PhysicalAttack {
    int singleAttackDamage();
    int doubleAttackDamage();
}

// 基本物理攻撃クラス
class BasicPhysicalAttack implements PhysicalAttack {
private static final int SINGLE_ATTACK_BASE = 50;
private static final int DOUBLE_ATTACK_BASE = 80;

    @Override
    public int singleAttackDamage() {
        return SINGLE_ATTACK_BASE;
    }

    @Override
    public int doubleAttackDamage() {
        return DOUBLE_ATTACK_BASE;
    }

}

// ファイター物理攻撃クラス（委譲を使用）
class FighterPhysicalAttack implements PhysicalAttack {
private static final int FIGHTER_BONUS = 20;
private final PhysicalAttack physicalAttack;

    FighterPhysicalAttack(final PhysicalAttack physicalAttack) {
        if (physicalAttack == null) {
            throw new NullPointerException("物理攻撃は必須です。");
        }
        this.physicalAttack = physicalAttack;
    }

    @Override
    public int singleAttackDamage() {
        return physicalAttack.singleAttackDamage() + FIGHTER_BONUS;
    }

    @Override
    public int doubleAttackDamage() {
        return physicalAttack.doubleAttackDamage() + FIGHTER_BONUS;
    }

}
</code>

<benefits>
- **疎結合**: FighterPhysicalAttackがBasicPhysicalAttackの実装詳細に依存しない
- **柔軟性向上**: インターフェース経由で異なる物理攻撃実装を注入可能
- **変更の局所化**: BasicPhysicalAttackの変更がFighterPhysicalAttackに影響しない
- **テスタビリティ向上**: モックやスタブを使った独立したテストが可能
- **単一責任**: 各クラスが明確な責任を持つ
- **デコレーターパターンの適用**: ボーナスダメージを追加する責務を分離
</benefits>
</example>

**設計原則:**

- **継承より委譲**: IS-A 関係が明確でない限り、委譲（コンポジション）を優先する
- **インターフェース経由の依存**: 具象クラスではなくインターフェースに依存する
- **脆い基底クラス問題の回避**: 継承階層を深くせず、浅く保つ

---

