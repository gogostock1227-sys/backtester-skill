# 評估指標系統

## 指標總覽

| 指標 | 公式 | 意義 | 目標 |
|------|------|------|------|
| **robustness_score** | 加權綜合 (0~100) | 最終排名依據 | 越高越好 |
| **NH** | max(equity peak gaps in days) | 最大未創新高天數 | <150 天 |
| **Total Return** | (final - init) / init * 100 | 總報酬率 | 穩定正值 |
| **Sharpe Ratio** | excess_return / volatility | 風險調整報酬 | >0.8 |
| **Sortino Ratio** | excess_return / downside_vol | 只懲罰下行 | >1.0 |
| **Max Drawdown** | (peak - trough) / peak * 100 | 最慘回撤 | <20% |
| **Calmar** | annual_return / max_drawdown | 報酬回撤比 | >1.0 |
| **Win Rate** | winning_trades / total_trades | 勝率 | 40~60% |
| **Profit Factor** | sum(wins) / abs(sum(losses)) | 獲利/虧損比 | >1.5 |
| **Num Trades** | 交易次數 | 統計顯著性 | 足夠取樣 |

## robustness_score 詳解

```python
def robustness_score(is_metrics, oos_metrics) -> float:
    """穩健度評分 (0~100)"""
```

### 權重分配

| 權重 | 維度 | 計算 | 正規化上限 |
|------|------|------|-----------|
| **25%** | Sharpe 平均 | (IS_sharpe + OOS_sharpe) / 2 | 2.0 |
| **25%** | IS/OOS 一致性 | 1 - abs(IS_ret - OOS_ret) / max(abs(IS_ret), 1) / 2 | — |
| **20%** | 低回撤 | 1 - avg_drawdown / 30 | 30% |
| **15%** | Sortino 平均 | (IS + OOS) / 2 | 3.0 |
| **15%** | Calmar 平均 | (IS + OOS) / 2 | 3.0 |

### 一致性加分
- OOS 報酬 > 0 時，一致性分數額外 +0.2（上限 1.0）
- 這確保 OOS 有正報酬的策略被優待

### 過擬合懲罰

| 情境 | IS Return | OOS Return | Score |
|------|-----------|------------|-------|
| 理想 | +50% | +40% | ~70+ |
| 良好 | +30% | +20% | ~55 |
| 過擬合 | +200% | -50% | ~5 |
| 雙負 | -10% | -5% | ~15 |

## NH (No New High) — 最大未創新高天數

### 定義

NH = 權益曲線從某個高點到下一個新高之間，最長的**日曆天**數。

### 為什麼 NH 重要

- **NH 大** = 策略有長期低迷期，實盤心理壓力大
- **NH 小** = 策略頻繁創新高，投資者信心好
- NH 是 robustness_score 沒直接包含但**策略品質極其關鍵**的指標

### 門檻建議

| NH | 評價 |
|----|------|
| <90 天 | 優秀 — 不到 3 個月就會創新高 |
| <150 天 | 良好 — 半年內必創新高 |
| <250 天 | 可接受 — 一年內會恢復 |
| >365 天 | 危險 — 可能結構性失效 |

### 計算方式

```python
def calc_max_no_new_high_days(equity):
    """計算最大 NH 天數"""
    running_max = equity.cummax()
    is_new_high = equity >= running_max
    nh_dates = equity.index[is_new_high]

    if len(nh_dates) < 2:
        return 9999

    gaps = []
    for i in range(len(nh_dates) - 1):
        gap = (nh_dates[i+1] - nh_dates[i]).days
        gaps.append(gap)
    return max(gaps)
```

### NH vs. Max Drawdown

| | NH | Max Drawdown |
|-|-----|-------------|
| 衡量什麼 | 恢復**時間** | 虧損**幅度** |
| 好策略 | 兩者都小 | 兩者都小 |
| 陷阱 | 小回撤但恢復慢 (NH大MDD小) | 大回撤但快速恢復 (NH小MDD大) |

## 指標解讀指南

### Sharpe Ratio

```
< 0    : 虧損策略
0 ~ 0.5: 很差
0.5~1.0: 一般
1.0~2.0: 良好
> 2.0  : 優秀 (也可能過擬合)
```

### Profit Factor

```
< 1.0  : 虧損
1.0~1.5: 勉強
1.5~2.0: 良好
> 2.0  : 優秀
```

### 指標間的相互驗證

優秀策略應該**所有指標都不差**，而非某個指標極好但其他很爛：

```
✅ Sharpe 1.2 + Sortino 1.5 + MDD 10% + NH 100 天 + WR 52%
❌ Sharpe 3.0 + Sortino 0.5 + MDD 25% + NH 300 天 + WR 80%
   (極端 Sharpe 暗示過擬合或計算異常)
```

## 標準化輸出格式

```
---
robustness_score: 45.2
is_return_pct: 15.3
oos_return_pct: 8.7
is_sharpe: 1.2345
oos_sharpe: 0.8765
is_sortino: 1.5678
oos_sortino: 1.0234
is_max_drawdown_pct: 12.34
oos_max_drawdown_pct: 15.67
is_calmar: 1.24
oos_calmar: 0.56
is_win_rate_pct: 55.0
oos_win_rate_pct: 48.0
is_num_trades: 45
oos_num_trades: 20
is_profit_factor: 1.85
oos_profit_factor: 1.32
elapsed_seconds: 3.2
```

解析：
```bash
grep "^robustness_score:\|^oos_return_pct:\|^oos_sharpe:\|^oos_max_drawdown_pct:" run.log
```

## 相關參考

- [回測引擎 API](backtesting-reference.md) — evaluate() 和 robustness_score() 實作
- [優化方法](optimization-reference.md) — 如何系統性提升各項指標
