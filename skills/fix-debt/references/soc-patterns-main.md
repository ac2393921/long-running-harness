# 関心の分離の検出基準 - 主要パターン

## 目次

- [パターン 1: インスタンス変数の混在](#パターン-1-インスタンス変数の混在)
- [パターン 2: 目的の混在](#パターン-2-目的の混在)
- [パターン 3: インターフェイスと実装の混在](#パターン-3-インターフェイスと実装の混在)

---

## 検出パターン

### パターン 1: インスタンス変数の混在

**症状:** 関係が弱いデータとロジックが同じクラスに混在している

<example type="bad">
<description>
Utilityクラスに異なる関心事（予約管理、ビュー設定、メールマガジン）が混在しており、クラスの責務が不明確になっている。
</description>

<code language="java">
class Utill {
    private int reservationId;
    private ViewSettings viewSettings;
    private MailMagazine mailMagazine;

    void cancelReservation() {
        // reservationIdを使った予約キャンセル処理
    }

    void darkMode() {
        // viewSettingsを使ったダークモード表示への変更処理
    }

    void beginSendMail() {
        // mailMagazineを使ったメール配信開始処理
    }

}
</code>

<issues>
- **単一責任の原則違反**: 1つのクラスが予約管理、ビュー設定、メール配信の3つの責任を持つ
- **低凝集性**: 関連性のないデータとメソッドが同居している
- **変更の影響範囲が不明確**: 予約システムの変更がビュー設定にも影響する可能性
- **テスタビリティの低下**: 特定の機能だけをテストすることが困難
- **再利用性の欠如**: 予約機能だけを別のシステムで使えない
- **命名の不適切さ**: "Util"という曖昧な名前が責務の不明確さを示す
</issues>
</example>

<example type="good">
<description>
各関心事を独立したクラスに分離し、それぞれの責務を明確にする。各クラスは自身のデータとロジックをカプセル化する。
</description>

<code language="java">
class Reservation {
    private final int reservationId;

    Reservation(final int reservationId) {
        if (reservationId <= 0) {
            throw new IllegalArgumentException("予約IDは1以上である必要があります。");
        }
        this.reservationId = reservationId;
    }

    void cancel() {
        // reservationIdを使った予約キャンセル処理
    }

}

class ViewCustomizing {
private final ViewSettings viewSettings;

    ViewCustomizing(final ViewSettings viewSettings) {
        if (viewSettings == null) {
            throw new NullPointerException("ビュー設定は必須です。");
        }
        this.viewSettings = viewSettings;
    }

    void darkMode() {
        // viewSettingsを使ったダークモード表示への変更処理
    }

}

class MailMagazineService {
private final MailMagazine mailMagazine;

    MailMagazineService(final MailMagazine mailMagazine) {
        if (mailMagazine == null) {
            throw new NullPointerException("メールマガジン設定は必須です。");
        }
        this.mailMagazine = mailMagazine;
    }

    void beginSendMail() {
        // mailMagazineを使ったメール配信開始処理
    }

}
</code>

<benefits>
- **単一責任**: 各クラスが明確な1つの責任を持つ
- **高凝集性**: 関連するデータとロジックが同じクラスに集約
- **変更の局所化**: 予約システムの変更はReservationクラスのみに影響
- **テスタビリティ向上**: 各機能を独立してテスト可能
- **再利用性向上**: 予約機能を他のシステムでも利用可能
- **理解しやすさ**: クラス名から責務が明確
- **保守性向上**: 影響範囲が限定され、変更が容易
</benefits>
</example>

---

### パターン 2: 目的の混在

**症状:** 異なる目的のロジックが 1 つのクラスに集約され、クラスが肥大化している

<example type="bad">
<description>
SellingPriceクラスに、販売価格に関連する様々な計算（販売手数料、配送料、ショッピングポイント）が集約されている。一見関連しているように見えるが、それぞれ異なる目的を持つ。
</description>

<code language="java">
class SellingPrice {
    private static final float SELLING_COMMISSION_RATE = 0.05f;
    private static final int DELIVERY_FREE_MIN = 2000;
    private static final float SHOPPING_POINT_RATE = 0.01f;

    final int amount;

    SellingPrice(final int amount) {
        if (amount < 0) {
            throw new IllegalArgumentException("価格が0以上でありません。");
        }
        this.amount = amount;
    }

    // 販売手数料を計算する
    int calcSellingCommission() {
        return (int) (amount * SELLING_COMMISSION_RATE);
    }

    // 配送料を計算する
    int calcDeliveryCharge() {
        return DELIVERY_FREE_MIN <= amount ? 0 : 500;
    }

    // 獲得するショッピングポイントを計算する
    int calcShoppingPoint() {
        return (int) (amount * SHOPPING_POINT_RATE);
    }

}
</code>

<issues>
- **複数の責任**: 販売価格、手数料、配送料、ポイントの4つの責任を持つ
- **変更理由の多様化**: 手数料率変更、配送料体系変更、ポイント制度変更など異なる理由で変更が必要
- **クラスの肥大化**: 関連する機能を追加するたびにクラスが肥大化する傾向
- **ドメイン概念の不明確化**: SellingPriceという名前なのにポイント計算も担当
- **再利用性の低下**: 手数料計算だけを別システムで使えない
- **テストの複雑化**: 1つのクラスで複数の異なるビジネスルールをテストする必要がある
- **単一責任の原則違反**: 価格が変わる理由とポイント制度が変わる理由は異なる
</issues>
</example>

<example type="good">
<description>
目的ごとに独立したクラスに分離し、各クラスがビジネスドメインの明確な概念を表現する。Value Objectパターンを適用し、不変性を確保する。
</description>

<code language="java">
// 販売価格クラス
class SellingPrice {
    final int amount;

    SellingPrice(final int amount) {
        if (amount < 0) {
            throw new IllegalArgumentException("価格は0以上である必要があります。");
        }
        this.amount = amount;
    }

}

// 販売手数料クラス
class SellingCommission {
private static final float SELLING_COMMISSION_RATE = 0.05f;
final int amount;

    SellingCommission(final SellingPrice sellingPrice) {
        if (sellingPrice == null) {
            throw new NullPointerException("販売価格は必須です。");
        }
        amount = (int) (sellingPrice.amount * SELLING_COMMISSION_RATE);
    }

}

// 配送料クラス
class DeliveryCharge {
private static final int DELIVERY_FREE_MIN = 2000;
private static final int STANDARD_CHARGE = 500;
final int amount;

    DeliveryCharge(final SellingPrice sellingPrice) {
        if (sellingPrice == null) {
            throw new NullPointerException("販売価格は必須です。");
        }
        amount = DELIVERY_FREE_MIN <= sellingPrice.amount ? 0 : STANDARD_CHARGE;
    }

}

// ショッピングポイントクラス
class ShoppingPoint {
private static final float SHOPPING_POINT_RATE = 0.01f;
final int value;

    ShoppingPoint(final SellingPrice sellingPrice) {
        if (sellingPrice == null) {
            throw new NullPointerException("販売価格は必須です。");
        }
        value = (int) (sellingPrice.amount * SHOPPING_POINT_RATE);
    }

}
</code>

<benefits>
- **単一責任**: 各クラスが1つの明確なビジネス概念を表現
- **変更の局所化**: 手数料率変更はSellingCommissionクラスのみに影響
- **ドメイン概念の明確化**: クラス名がビジネスドメインの概念と一致
- **再利用性向上**: 各クラスを独立して他のシステムで利用可能
- **テスタビリティ向上**: 各ビジネスルールを独立してテスト可能
- **拡張性向上**: 新しい料金体系（例：会員割引）を追加しても既存クラスに影響なし
- **理解しやすさ**: クラスの責務が名前から明確に理解できる
- **保守性向上**: ビジネスルール変更時の影響範囲が限定される
</benefits>
</example>

---

### パターン 3: インターフェイスと実装の混在

**症状:** 様々な関心ごと（ダメージ計算、武器耐久度、ゲージ増加など）が 1 つの処理に混在し、複雑で理解困難なロジックになっている

<example type="bad">
<description>
ダメージ計算ロジックに、武器耐久度の管理、スペシャルゲージの増加、防御力計算など複数の関心事が入り混じっている。条件分岐が深くネストし、何をしているのか理解しづらい。
</description>

<code language="java">
int damage = 0;
if (0 < weapon.durability) {
    damage = (member.armPower + weapon.power) - enemy.defence / 2;
    if (damage > 0) {
        if (specialGauge.amount == 100) {
            damage *= 2;
        }
    }
    else {
        damage = 0;
    }
    if (specialGauge.amount < 100) {
        if (damage < 10) {
            weapon.durability -= 1;
        }
    }
    specialGauge.amount += 5 + damage / 100;
    if (specialGauge.amount > 100) {
        specialGauge.amount = 100;
    }
}
else {
    throw new RuntimeException("この武器では攻撃できません。");
}
</code>

<issues>
- **関心の混在**: ダメージ計算、武器耐久度管理、ゲージ増加が混在
- **深いネスト**: 条件分岐が深くネストし、可読性が低い
- **カプセル化の欠如**: 各クラスの内部状態を直接操作している
- **テスタビリティの低下**: 複雑なロジックを1つのテストで検証する必要がある
- **変更の困難さ**: ダメージ計算式を変更すると他の部分にも影響する可能性
- **再利用性の欠如**: この処理を他の場面で使えない
- **バグの混入しやすさ**: 複雑な条件分岐でバグが混入しやすい
- **Tell, Don't Ask違反**: オブジェクトの状態を取得して外部で判断している
</issues>
</example>

<example type="good">
<description>
インターフェイスと実装を分離し、各クラスが自身の責任を持つ。完全コンストラクタパターンとTell, Don't Askの原則を適用し、オブジェクトに判断と操作を委譲する。
</description>

<code language="java">
// ダメージクラス
class Damage {
    final int amount;

    Damage(final Member member, final Weapon weapon, final SpecialGauge specialGauge, final Enemy enemy) {
        if (member == null) throw new NullPointerException("メンバーは必須です。");
        if (weapon == null) throw new NullPointerException("武器は必須です。");
        if (specialGauge == null) throw new NullPointerException("スペシャルゲージは必須です。");
        if (enemy == null) throw new NullPointerException("敵は必須です。");

        final int basicAmount = Math.max(0, (member.armPower + weapon.power) - enemy.defence / 2);
        amount = specialGauge.isFull() ? basicAmount * 2 : basicAmount;
    }

}

// 武器クラス
class Weapon {
private static final int MIN_POWER = 1;
private static final int BREAK_THRESHOLD = 10;
private static final int MIN_DURABILITY = 0;

    final String name;
    final int power;
    final int durability;

    Weapon(final String name, final int power, final int durability) {
        if (name == null || name.isEmpty()) {
            throw new IllegalArgumentException("武器名は必須です。");
        }
        if (power < MIN_POWER) {
            throw new IllegalArgumentException("武器の攻撃力は1以上である必要があります。");
        }
        if (durability < MIN_DURABILITY) {
            throw new IllegalArgumentException("武器の耐久力は0以上である必要があります。");
        }

        this.name = name;
        this.power = power;
        this.durability = durability;
    }

    boolean canUse() {
        return MIN_DURABILITY < durability;
    }

    Weapon use(final Damage damage, final SpecialGauge specialGauge) {
        if (!canUse()) {
            throw new RuntimeException("この武器では攻撃できません。");
        }
        if (damage == null) throw new NullPointerException("ダメージは必須です。");
        if (specialGauge == null) throw new NullPointerException("スペシャルゲージは必須です。");

        if (!specialGauge.isFull() && damage.amount < BREAK_THRESHOLD) {
            return new Weapon(name, power, durability - 1);
        }
        return this;
    }

}

// スペシャルゲージクラス
class SpecialGauge {
private static final int MIN = 0;
private static final int MAX = 100;
private static final int BASIC_INCREASE_AMOUNT = 5;

    final int amount;

    SpecialGauge(final int amount) {
        if (amount < MIN || MAX < amount) {
            throw new IllegalArgumentException("スペシャルゲージは0~100である必要があります。");
        }
        this.amount = amount;
    }

    SpecialGauge increase(final Damage damage) {
        if (damage == null) throw new NullPointerException("ダメージは必須です。");

        final int increaseAmount = BASIC_INCREASE_AMOUNT + damage.amount / 100;
        final int newAmount = Math.min(amount + increaseAmount, MAX);

        return new SpecialGauge(newAmount);
    }

    boolean isFull() {
        return amount == MAX;
    }

}

// 使用例
if (!weapon.canUse()) {
throw new RuntimeException("この武器では攻撃できません。");
}
final Damage damage = new Damage(member, weapon, specialGauge, enemy);
final Weapon usedWeapon = weapon.use(damage, specialGauge);
final SpecialGauge increasedSpecialGauge = specialGauge.increase(damage);
</code>

<benefits>
- **関心の分離**: ダメージ、武器、ゲージがそれぞれ独立したクラス
- **高凝集性**: 関連するデータとロジックが同じクラスに集約
- **カプセル化**: 各クラスが自身の状態を管理し、外部に公開しない
- **インターフェイスの明確化**: `canUse()`, `use()`, `increase()`, `isFull()` など明確なメソッド名
- **不変性の確保**: 状態変更時は新しいインスタンスを返す
- **テスタビリティ向上**: 各クラスを独立してテスト可能
- **可読性向上**: ネストが浅く、何をしているか理解しやすい
- **変更の局所化**: ダメージ計算式の変更はDamageクラスのみに影響
- **Tell, Don't Ask原則の遵守**: オブジェクトに判断と操作を委譲
</benefits>
</example>

---

