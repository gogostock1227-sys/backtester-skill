# Evaluation Metrics System

## Metrics Overview

| Metric | Formula | Meaning | Target |
|--------|---------|---------|--------|
| **robustness_score** | Weighted composite (0~100) | THE ranking metric | Higher is better |
| **NH** | max(equity peak gap in calendar days) | Max days without new equity high | <150 days |
| **Total Return** | (final - init) / init * 100 | Total return % | Stable positive |
| **Sharpe Ratio** | excess_return / volatility | Risk-adjusted return | >0.8 |
| **Sortino Ratio** | excess_return / downside_vol | Penalizes only downside | >1.0 |
| **Max Drawdown** | (peak - trough) / peak * 100 | Worst underwater % | <20% |
| **Calmar** | annual_return / max_drawdown | Return per unit of risk | >1.0 |
| **Win Rate** | winning / total trades | Hit rate | 40~60% |
| **Profit Factor** | sum(wins) / abs(sum(losses)) | Gain/loss ratio | >1.5 |

## robustness_score In Depth

### Weight Distribution

| Weight | Dimension | Calculation | Cap |
|--------|-----------|-------------|-----|
| **25%** | Avg Sharpe | (IS + OOS) / 2 | 2.0 |
| **25%** | IS/OOS Consistency | 1 - abs(IS_ret - OOS_ret) / max(abs(IS_ret),1) / 2 | — |
| **20%** | Low Drawdown | 1 - avg_drawdown / 30 | 30% |
| **15%** | Avg Sortino | (IS + OOS) / 2 | 3.0 |
| **15%** | Avg Calmar | (IS + OOS) / 2 | 3.0 |

### Consistency Bonus
- OOS return > 0 → consistency score gets +0.2 (capped at 1.0)
- This ensures strategies with positive OOS are rewarded

### Overfitting Penalty Examples

| Scenario | IS Return | OOS Return | Score |
|----------|-----------|------------|-------|
| Ideal | +50% | +40% | ~70+ |
| Good | +30% | +20% | ~55 |
| Overfit | +200% | -50% | ~5 |
| Both negative | -10% | -5% | ~15 |

## NH (No New High) — Max Days Without New Equity High

### Definition

NH = the longest gap (in calendar days) between consecutive equity curve peaks.

### Why NH Matters

- **Large NH** = Strategy has extended flat/down periods; real-money psychological pressure is high
- **Small NH** = Strategy frequently makes new highs; investor confidence stays strong
- NH is the single most important metric that `robustness_score` doesn't directly include

### Recommended Thresholds

| NH | Rating |
|----|--------|
| <90 days | Excellent — new high every 3 months |
| <150 days | Good — new high within 6 months |
| <250 days | Acceptable — recovers within a year |
| >365 days | Dangerous — possible structural failure |

### Calculation

```python
def calc_max_no_new_high_days(equity):
    running_max = equity.cummax()
    is_new_high = equity >= running_max
    nh_dates = equity.index[is_new_high]

    if len(nh_dates) < 2:
        return 9999

    gaps = [(nh_dates[i+1] - nh_dates[i]).days for i in range(len(nh_dates)-1)]
    return max(gaps)
```

### NH vs. Max Drawdown

| | NH | Max Drawdown |
|-|-----|-------------|
| Measures | Recovery **time** | Loss **magnitude** |
| Good strategy | Both small | Both small |
| Trap | Small DD but slow recovery (high NH) | Large DD but fast bounce (low NH) |

## Interpreting Metrics

### Sharpe Ratio
```
< 0    : Losing strategy
0~0.5  : Poor
0.5~1.0: Average
1.0~2.0: Good
> 2.0  : Excellent (or possibly overfit)
```

### Profit Factor
```
< 1.0  : Losing
1.0~1.5: Marginal
1.5~2.0: Good
> 2.0  : Excellent
```

### Cross-Validation Between Metrics

A good strategy should have **all metrics at acceptable levels**, not one extreme metric with others falling apart:

```
Good:  Sharpe 1.2 + Sortino 1.5 + MDD 10% + NH 100d + WR 52%
Bad:   Sharpe 3.0 + Sortino 0.5 + MDD 25% + NH 300d + WR 80%
       (Extreme Sharpe hints at overfitting or calculation anomaly)
```

## Standardized Output Format

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

Parse with:
```bash
grep "^robustness_score:\|^oos_return_pct:\|^oos_sharpe:\|^oos_max_drawdown_pct:" run.log
```

## References

- [Backtest Engine API](backtesting-reference.en.md) — evaluate() and robustness_score() implementation
- [Optimization Methods](optimization-reference.en.md) — How to systematically improve metrics
