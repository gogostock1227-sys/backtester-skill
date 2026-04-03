# Visualization System

## Generated Charts

`plot_equity.py` produces:

| Chart | Filename | Content |
|-------|----------|---------|
| Full Period | `backtest_full_period.png` | Full data single-pass equity + drawdown |
| Chained Equity | `backtest_full.png` | IS + OOS chained, OOS starts from IS end value |
| In-Sample | `backtest_IS.png` | IS-only equity + drawdown |
| Out-of-Sample | `backtest_OOS.png` | OOS-only equity + drawdown |
| Combined Summary | `backtest_result.png` | Equity + drawdown + performance table |

## Chart Layout

### Equity + Drawdown (Standard Two-Panel)
```
┌────────────────────────────────────┐
│  Equity Curve (Portfolio Value)     │  ← Top 3/4
│  IS (blue) + OOS (red) + split line│
├────────────────────────────────────┤
│  Drawdown (%)                       │  ← Bottom 1/4
│  IS DD (blue) + OOS DD (red)        │
└────────────────────────────────────┘
```

### Performance Summary Table
```
┌──────────┬───────────┬────────────┐
│  Metric  │  IS       │  OOS       │
├──────────┼───────────┼────────────┤
│  Return  │  +45.23%  │  +18.56%   │
│  Sharpe  │  1.2345   │  0.8765    │
│  ...     │  ...      │  ...       │
└──────────┴───────────┴────────────┘
```

## NH Calculation

```python
def calc_max_no_new_high_days(eq):
    running_max = eq.cummax()
    underwater = eq < running_max
    if not underwater.any():
        return 0
    groups = (~underwater).cumsum()
    max_days = 0
    for g, sub in underwater.groupby(groups):
        if sub.any():
            days = (sub[sub].index[-1].date() - sub[sub].index[0].date()).days
            max_days = max(max_days, days)
    return max_days
```

## Usage

```bash
# Generate all charts
python plot_equity.py

# Calculate NH only
python calc_nh.py
# Output:
# nh_max_days: 145
# nh_period: 2023-05-15 ~ 2023-10-07
# nh_2nd: 98 days (...)
# total_return: 1687.3%
# max_drawdown: 8.5%
```

## Color Scheme

| Element | Color | Usage |
|---------|-------|-------|
| IS Equity | `#2196F3` (blue) | In-sample curve |
| OOS Equity | `#FF5722` (red) | Out-of-sample curve |
| Full Period | `#4CAF50` (green) | Full period curve |
| Split Line | `gray --` | IS/OOS boundary |
| Table Header | `#E3F2FD` | Summary table header |

## CJK Font Setup (for Chinese/Japanese/Korean labels)

```python
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams['font.sans-serif'] = ['Microsoft JhengHei', 'SimHei', 'Arial']
plt.rcParams['axes.unicode_minus'] = False
```

## References

- [Backtest Engine API](backtesting-reference.en.md) — Portfolio methods
- [Evaluation Metrics](metrics-reference.en.md) — Metric definitions in charts
