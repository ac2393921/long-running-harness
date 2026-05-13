# 条件分岐

## 条件分岐のネストによる可読性低下

悪い例

- 生存していること
- 行動可能であること
- 魔法力が残存していること

がネストしていて可読性が低下している

```java
// 生存しているか判定
if (0 < member.hitPoint) {
    // 行動可能かを判定
    if (member.canAct()) {
        // 魔法力が残存しているかを判定
        if (magic.costMagicPoint <= member.magicPoint) {
            member.consumeMagicPoint(magic.costMagicPoint);
            member.chant(magic);
        }
    }
}
```

良い例

早期returnでネストをなくす

```java
if (member.hitPoint <= 0) return;
if (!member.canAct()) return;
if (member.magicPoint < magic.costMagicPoint) return;

member.consumeMagicPoint(magic.costMagicPoint);
member.chant(magic);
```

## コードの見通しを悪くするelse句も早期returnで解決

悪い例

```java
float hitPointRate = member.hitPoint / member.maxHitPoint;
HealthCondition currentHealthCondition;

if (hitPointRate == 0) {
    currentHealthCondition = HealthCondition.dead;
}
else if (hitPointRate < 0.3) {
    currentHealthCondition = HealthCondition.danger;
}
else if (hitPointRate < 0.5) {
    currentHealthCondition = HealthCondition.caution;
}
else if (hitPointRate < 1) {
    currentHealthCondition = HealthCondition.fine;
}
else {
    currentHealthCondition = HealthCondition.fine;
}

return currentHealthCondition;

```

良い例

```java
float hitPointRate = member.hitPoint / member.maxHitPoint;

if (hitPointRate == 0) return HealthChondition.dead;
if (hitPointRate < 0.3) return HealthCondition.danger;
if (hitPointRate < 0.5) return HealthCondition.caution;

return HealthCondition.fine;
```