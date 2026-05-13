# 関心の分離の検出基準 - 具体的事例

## 目次

- [なんでも public](#なんでも-public)
- [privateメソッドだらけ](#privateメソッドだらけ)
- [スマートUI（利口なUI）](#スマートui利口なui)
- [巨大データクラス](#巨大データクラス)
- [神クラス](#神クラス)

---

## 関心が混在する各種事例と対処方法

### なんでも public

```java
package rpg.objects;

public class HitPointRecovery {
    public HitPointRecovery(final Member chanter, final int targetMemberId, final PositiveFeelings positiveFeelings) {
        final int basicRecoverAmount = (int)(chanter.magicPower * MAGIC_POWER_COEFFICIENT) + (int)(chanter.affection * AFFECTION_COEFFICIENT * positiveFeelings.value(chanter.id, targetMemberId));
    }
}

public class PositiveFeelings {
    * @param targetId 好意の対象となるメンバーID
    */
    public int value(int subjectId, int targetId) { ... }

    /**
     * 好感度を増加させる。
     * @param subjectId 好感度を増加させたいメンバーID
     * @param targetId 好意の対象となるメンバーID
     */
    public void increase(int subjectId, int targetId) { ... }

    /**
     * 好感度を減少させる。
     * @param subjectId 好感度を減少させたいメンバーID
     * @param targetId 好意の対象となるメンバーID
     */
    public void decrease(int subjectId, int targetId) { ... }
}
```

悪い例

PositiveFeelings は隠し要素です。画面上への表示もしたくないですし、
ましてや外部からの制御を受けたくはありません。内部的な制御にとどめておきたいクラスです。

BattleView は rpg.view パッケージで、PositiveFeelings とはパッケージが異なります。
しかしながら、PositiveFeelings が public で宣言されているためPositiveFeelings へアクセスできてしまう

```java
package rpg.view;
import rpg.objects;

/** 戦闘画面 */
public class BattleView {
    // 中略

    /** 攻撃アニメーションを開始する */
    public void startAttackAnimation() {
        // 中略
        positiveFeelings.increase(member1.id, member2.id);
    }
}
```

良い例

```java
package rpg.objects;

// アクセス修飾子を省略すると
// 可視性が package private になる。
// パッケージ内でのみアクセス可能。
class PositiveFeelings {
    int value(final int subjectId, final int targetId) { ... }

    void increase(final int subjectId, final int targetId) { ... }

    void decrease(final int subjectId, final int targetId) { ... }
}
```

### privateメソッドだらけ

privateメソッドが多いクラスはさまざまな関心を扱っていることが多い

悪い例
```java
class OrderService {
    private int clacDiscountPrice(int price) {
        // 割引価格を計算するロジック
    }

    private List<Product> getProductBrowsingHistory(int userId) {
        // 商品の閲覧履歴を取得するロジック
    }
}
```

良い例

関心の異なるメソッドを別々のクラスに分離する

```java
class DiscountPrive {
    public int clacDiscountPrice(int price) {
        // 割引価格を計算するロジック
    }
}

class ProductBrowsingHistory {
    public List<Product> getProductBrowsingHistory(int userId) {
        // 商品の閲覧履歴を取得するロジック
    }
}
```

### スマートUI（利口なUI）

表示関連のクラスの中に、表示以外のロジックが実装されている構造

```java
package rpg.view;

import rpg.objects.Member;
import rpg.objects.PositiveFeelings;
import rpg.persistence.BattleResultRepository;

import java.util.Random;

/**
 * 戦闘画面（UI）
 * なのに、戦闘ロジックも永続化も担当してしまっている「スマートUI」例。
 */
public class BattleView {

    private final Random random = new Random();

    // 本来はUIが直接触るべきでない
    private final PositiveFeelings positiveFeelings;         // ドメイン寄り
    private final BattleResultRepository repository;         // 永続化

    public BattleView(PositiveFeelings positiveFeelings, BattleResultRepository repository) {
        this.positiveFeelings = positiveFeelings;
        this.repository = repository;
    }

    /**
     * 攻撃ボタンが押された想定
     */
    public void onClickAttack(Member attacker, Member defender) {
        // ❌ UIが戦闘ロジックを持っている（ダメージ計算）
        int damage = calcDamage(attacker.getAttack(), defender.getDefense());
        defender.setHp(defender.getHp() - damage);

        // ❌ UIが状態遷移ルールを持っている（HP0判定）
        boolean finished = defender.getHp() <= 0;

        // ❌ UIが別のドメイン状態も更新している（好感度）
        if (!finished && damage >= 10) {
            positiveFeelings.increase(attacker.getId(), defender.getId());
        } else {
            positiveFeelings.decrease(attacker.getId(), defender.getId());
        }

        // ❌ UIが永続化までやっている
        repository.save(attacker.getId(), defender.getId(), damage, finished);

        // ✅ 表示更新（これはUIの責務）
        render(attacker, defender, damage, finished);
    }

    // ❌ UI内にビジネスルールが埋まっている
    private int calcDamage(int attack, int defense) {
        int base = attack - defense;
        int luck = random.nextInt(3); // 0..2
        return Math.max(1, base + luck);
    }

    private void render(Member attacker, Member defender, int damage, boolean finished) {
        System.out.println(attacker.getName() + " の攻撃！");
        System.out.println(defender.getName() + " に " + damage + " ダメージ！");
        System.out.println(defender.getName() + " のHP: " + defender.getHp());
        if (finished) System.out.println(defender.getName() + " は倒れた！");
    }
}
```

### 巨大データクラス

悪い例

巨大データクラスはさまざまなデータを持つためにあらゆるユースケースで使われる。
グローバル変数の性質を帯びてくる。
排他制御のためにパフォーマンスが低下するなど、グローバル変数と同様の弊害を招く

```java
public class Order {
    public int orderId;
    public int customerId;
    public List<Producct> products;
    public ZonedDataTime orderTime;
    public OrderState orderState;
    public int reservationId;
    public ZonedDateTime reservationDateTime;
    // ...
}
```

### 神クラス
