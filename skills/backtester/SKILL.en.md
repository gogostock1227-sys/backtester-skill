---
name: backtester
description: Universal futures/stock backtesting framework. Covers strategy development, backtest engine, IS/OOS validation, robustness scoring, NH calculation, parameter optimization, visualization. Works with any asset at any bar frequency. Trigger on: backtest, strategy, robustness, NH, optimize, autoresearch.
compatibility: Python 3.10+, vectorbt, TA-Lib, pandas_ta
---

# Backtester — Universal Systematic Trading Strategy Backtesting Framework

## Prerequisites

**Verify in order before starting:**

1. **Python installed** (3.10+):

   ```bash
   python --version
   ```

2. **Install all dependencies**:

   ```bash
   pip install vectorbt pandas numpy matplotlib openpyxl
   pip install pandas_ta
   ```

3. **Install TA-Lib** (C library + Python wrapper):

   TA-Lib requires the C library first, then the Python binding.

   **Windows (pre-compiled wheel recommended):**
   ```bash
   # Download matching wheel from https://github.com/cgohlke/talib-build/releases
   pip install TA_Lib-0.4.32-cp313-cp313-win_amd64.whl
   ```

   **macOS:**
   ```bash
   brew install ta-lib
   pip install TA-Lib
   ```

   **Linux (Ubuntu/Debian):**
   ```bash
   sudo apt-get install -y build-essential wget
   wget https://github.com/TA-Lib/ta-lib/releases/download/v0.6.4/ta-lib-0.6.4-src.tar.gz
   tar -xzf ta-lib-0.6.4-src.tar.gz
   cd ta-lib-0.6.4 && ./configure --prefix=/usr && make && sudo make install
   pip install TA-Lib
   ```

   **Verify:**
   ```bash
   python -c "import talib; print(talib.__version__)"
   ```

   Full install docs: https://ta-lib.org/install/

4. **Prepare OHLCV data file** (Excel or CSV):

   ```
   Columns: date, time, open, high, low, close, volume
   Format: sorted by time, no gaps
   ```

## Language

**Respond in the user's language.**

## Design Philosophy

1. **Robustness > Returns** — IS/OOS consistency over one-sided high returns
2. **NH First** — Max No-New-High days is the core quality measure
3. **Simplicity** — Given equal results, simpler is better
4. **Engine Immutability** — Backtest engine is separated from strategy
5. **Reproducibility** — Every change has a git commit

## Scope

| Dimension | Supported |
|-----------|-----------|
| Assets | Stock futures, index futures, ETFs, stocks, crypto |
| Timeframes | 1-min, 5-min, 15-min, 60-min, daily, weekly |
| Markets | Taiwan, US, China, forex, crypto |

Adapt by modifying data loading and trading costs in `prepare.py`.

## Quick Start

```python
# strategy.py — minimal complete example
import pandas as pd
import talib

def strategy(df):
    close = df['close'].values
    ema_f = pd.Series(talib.EMA(close, timeperiod=16), index=df.index)
    ema_m = pd.Series(talib.EMA(close, timeperiod=40), index=df.index)

    entries = (ema_f > ema_m) & (ema_f.shift(1) <= ema_m.shift(1))
    exits   = (ema_f < ema_m) & (ema_f.shift(1) >= ema_m.shift(1))
    return entries, exits

if __name__ == "__main__":
    from prepare import run_experiment
    run_experiment(strategy)
```

Run:
```bash
python strategy.py           # Backtest + print metrics
python plot_equity.py        # Generate performance charts
python calc_nh.py            # Calculate NH days
```

## Core Workflow: 5-Step Strategy Development

### Step 1: Prepare Data

Modify `load_data()` in `prepare.py` to load your OHLCV data:

```python
DATA_FILE = "my_data.xlsx"
def load_data():
    df = pd.read_excel(DATA_FILE)
    df.columns = ['date', 'time', 'open', 'high', 'low', 'close', 'volume']
    df['datetime'] = pd.to_datetime(df['date'].astype(str) + ' ' + df['time'].astype(str))
    df = df.set_index('datetime').sort_index()
    return df[['open', 'high', 'low', 'close', 'volume']].astype(float)
```

Set trading costs:
```python
TOTAL_FEE_RATE = 0.00003   # Adjust per asset
SLIPPAGE = 0.001            # Slippage
```

### Step 2: Write Strategy

Only modify `strategy.py`. Function signature:

```python
def strategy(df):
    """
    Input:  DataFrame (open, high, low, close, volume; index=datetime)
    Output: 2-tuple (entries, exits) or 4-tuple (+short_entries, +short_exits)
            Each is a bool Series
    """
    return entries, exits, short_entries, short_exits
```

Use `talib` (150+ indicators) and `pandas_ta` for calculations:
- **TA-Lib functions**: https://ta-lib.org/functions/
- **pandas_ta docs**: https://github.com/twopirllc/pandas_ta

### Step 3: Backtest

```bash
python strategy.py > run.log 2>&1
```

Auto pipeline: Load → IS/OOS split (70/30) → Backtest both → Evaluate → Print metrics.

### Step 4: Evaluate

Key output:
```
robustness_score: 85.0        ← THE ranking metric (0~100)
is_return_pct / oos_return_pct ← IS/OOS consistency is key
```

Plus NH:
```bash
python calc_nh.py    # nh_max_days: 145
```

### Step 5: Iterate

```bash
# Edit strategy.py → commit → backtest → compare score
git commit -m "v64: adjust KAMA exit"
python strategy.py > run.log 2>&1
grep "^robustness_score:" run.log
# Keep if improved, reset if not
```

## Standard Project Structure

```
project/
├── prepare.py           ← Fixed infrastructure (DO NOT MODIFY)
├── strategy.py          ← Only modifiable: strategy logic
├── plot_equity.py       ← Visualization
├── calc_nh.py           ← NH calculation
├── optimize.py          ← Grid search
├── program.md           ← Experiment protocol
├── results.tsv          ← Experiment log
└── *.xlsx / *.csv       ← OHLCV data
```

## Reference Files

| File | Content |
|------|---------|
| [backtesting-reference.en.md](backtesting-reference.en.md) | prepare.py API, Portfolio usage, cost settings |
| [strategy-reference.en.md](strategy-reference.en.md) | Signal design patterns, entry/exit templates |
| [metrics-reference.en.md](metrics-reference.en.md) | robustness score, NH, performance metrics |
| [optimization-reference.en.md](optimization-reference.en.md) | Grid search, autoresearch loop, methodology |
| [visualization-reference.en.md](visualization-reference.en.md) | Chart generation and interpretation |

## Prevent Overfitting

**Core rule:** Always look at IS AND OOS together:

```
✅ IS +50% / OOS +40%  → Robust, keep
❌ IS +200% / OOS -50% → Overfit, discard
✅ IS +20% / OOS +15%  → Low return but robust, worth optimizing
```

## External References

- **TA-Lib Indicators**: https://ta-lib.org/functions/
- **TA-Lib Installation**: https://ta-lib.org/install/
- **pandas_ta**: https://github.com/twopirllc/pandas_ta
- **vectorbt**: https://vectorbt.dev/
