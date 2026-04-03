# Backtest Engine API (prepare.py)

> `prepare.py` is fixed infrastructure. **DO NOT MODIFY.** Strategy only imports and calls it.

## Data Loading

### `load_data() -> DataFrame`

Loads OHLCV data, returns standardized DataFrame.

```python
from prepare import load_data
df = load_data()
# columns: open, high, low, close, volume
# index: datetime
```

**Adapting to different assets/timeframes:**
```python
# Example: Load 5-min candles from CSV
DATA_FILE = "my_stock_5min.csv"
def load_data():
    df = pd.read_csv(DATA_FILE, parse_dates=['datetime'], index_col='datetime')
    return df[['open', 'high', 'low', 'close', 'volume']].astype(float)
```

### `split_data(df, train_ratio=0.7) -> (df_is, df_oos)`

Time-series split. **NOT random sampling.** Prevents look-ahead bias.

## Backtest Engine

### `run_backtest(close, entries, exits, short_entries=None, short_exits=None, init_cash=1_000_000) -> Portfolio`

Wrapper around vectorbt `Portfolio.from_signals()`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `close` | Series | Close prices |
| `entries` | Series[bool] | Long entry signals |
| `exits` | Series[bool] | Long exit signals |
| `short_entries` | Series[bool] | Short entry (optional) |
| `short_exits` | Series[bool] | Short exit (optional) |
| `init_cash` | float | Starting capital |

**Trading costs (adjust per asset):**

```python
# Taiwan stock futures
TOTAL_FEE_RATE = 0.00003; SLIPPAGE = 0.001; FREQ = '60min'

# US stocks (zero-commission broker)
TOTAL_FEE_RATE = 0.0; SLIPPAGE = 0.0005; FREQ = 'D'

# Crypto (Binance maker)
TOTAL_FEE_RATE = 0.001; SLIPPAGE = 0.002; FREQ = '15min'
```

### Portfolio Methods

```python
pf.value()                     # Equity curve (Series)
pf.total_return()              # Total return (0.15 = 15%)
pf.sharpe_ratio()              # Annualized Sharpe
pf.sortino_ratio()             # Annualized Sortino
pf.max_drawdown()              # Max drawdown (negative)
pf.drawdown()                  # Drawdown series
pf.trades.records_readable     # Trade details (with PnL)
```

## Evaluation

### `evaluate(pf, label="") -> dict`

| Field | Description | Healthy Range |
|-------|-------------|---------------|
| `total_return_pct` | Total return % | Depends on period |
| `sharpe` | Sharpe ratio | >0.8 |
| `sortino` | Sortino ratio | >1.0 |
| `max_drawdown_pct` | Max drawdown % (positive) | <20% |
| `calmar` | Return / drawdown | >1.0 |
| `win_rate_pct` | Win rate % | 40~60% |
| `num_trades` | Trade count | Enough for significance |
| `profit_factor` | Gross profit / gross loss | >1.5 |

### `robustness_score(is_metrics, oos_metrics) -> float`

Robustness score (0~100). **THE ranking metric.**

| Weight | Dimension | Cap | Purpose |
|--------|-----------|-----|---------|
| 25% | Avg Sharpe | 2.0 | Risk-adjusted return |
| 25% | IS/OOS Consistency | — | Anti-overfitting (OOS>0 gets +0.2 bonus) |
| 20% | Low Drawdown | 30% | Risk control |
| 15% | Avg Sortino | 3.0 | Downside risk |
| 15% | Avg Calmar | 3.0 | Return/drawdown |

## Main Pipeline

### `run_experiment(strategy_func)`

Load → Split → Run strategy on IS & OOS → Backtest both → Evaluate → Print standardized output.

```
---
robustness_score: 45.2
is_return_pct: 15.3
oos_return_pct: 8.7
...
```

## Signal Design Patterns

### Crossover / Crossunder
```python
golden = (fast > slow) & (fast.shift(1) <= slow.shift(1))
death  = (fast < slow) & (fast.shift(1) >= slow.shift(1))
```

### N-Bar Confirmation
```python
cond = close < threshold
cond_3 = cond & cond.shift(1) & cond.shift(2)
```

### Streak Counter
```python
flag = (close > ema).astype(int)
streak = flag.groupby((~flag.astype(bool)).cumsum()).cumsum()
extended = streak > 120
```

### Multi-Signal Composition
```python
entries = (sig_a | sig_b | sig_c) & filter_1 & filter_2 & ~suppress
exits   = exit_a | exit_b | exit_c
```

## References

- [Strategy Architecture](strategy-reference.en.md)
- [Evaluation Metrics](metrics-reference.en.md)
- [Optimization Methods](optimization-reference.en.md)
