# Strategy Architecture — Signal Design Patterns

> For indicator calculation details, see [TA-Lib Functions](https://ta-lib.org/functions/) and [pandas_ta](https://github.com/twopirllc/pandas_ta).
> This document focuses on **how to combine indicators into strategies**, not the indicators themselves.

## Five-Layer Signal Architecture

A complete strategy has entry, filter, and exit layers. Recommended 5-layer design:

```
Layer 1: Trend Detection   → Direction (MAs / Channels / MACD)
Layer 2: Precise Entry     → Timing (Oscillators / Breakout)
Layer 3: Special Scenarios  → Crash recovery / Extreme conditions
Layer 4: External Factors   → VIX / Market index / Cross-market
Layer 5: Filters & Confirm  → Volume / Crash protection / Overheating
```

Each layer is designed independently, then combined with boolean logic.

## Signal Design Patterns

### Crossover / Crossunder

The most fundamental signal type. Two lines crossing.

```python
golden = (fast > slow) & (fast.shift(1) <= slow.shift(1))
death  = (fast < slow) & (fast.shift(1) >= slow.shift(1))
```

### Oversold/Overbought Bounce

Oscillator recovering from extreme zone.

```python
# RSI oversold bounce
entry = (rsi > 30) & (rsi.shift(1) <= 30)
# CCI deep oversold recovery
entry = (cci > -50) & (cci.shift(1) <= -80)
# MFI with rolling window extreme confirmation
entry = (mfi > 25) & (mfi.shift(1) <= 25) & (mfi.rolling(10).min() < 18)
```

### N-Bar Confirmation

Reduce noise by requiring signal persistence.

```python
cond = close < threshold
cond_3 = cond & cond.shift(1) & cond.shift(2)  # 3 consecutive bars
```

### Streak Counter

Count consecutive bars a condition holds.

```python
flag = (close > ema).astype(int)
streak = flag.groupby((~flag.astype(bool)).cumsum()).cumsum()
extended = streak > 120
```

### Breakout

Price breaks above prior high.

```python
donchian_high = high.rolling(N).max()
breakout = (close > donchian_high.shift(1)) & (close.shift(1) <= donchian_high.shift(2))
```

### Crash Detection & Recovery

```python
bounce = (close > close.shift(2)) & (close > tema)
crash = (close.rolling(25).min() / close.rolling(25).max() - 1) < -0.15
recovery = crash & bounce & vol_confirm
```

### Adaptive Logic (ADX/VIX Switching)

Switch parameters based on market regime.

```python
kama_exit = np.where(adx > 33, kama_slow, kama_fast)
adaptive_gap = np.where(vix < 18, 0.01, 0.0)
```

## Composition Logic

### Multi-Signal OR Entry + AND Filters

```python
entries = (trend_sig | osc_sig | recovery_sig) & filter_1 & filter_2 & ~suppress
exits   = exit_fast | exit_patient | exit_protect | exit_danger
```

### Common Filters

```python
vol_confirm = volume > volume.rolling(20).mean() * 0.65
not_crashing = (close - high.rolling(100).max()) / high.rolling(100).max() > -0.06
bullish_bar = close > open
obv_rising = obv > obv.rolling(20).mean()
```

### Oscillator + Trend Filter

Oscillators (RSI/StochRSI/CCI/MFI) alone are noisy. Always add trend filter:

```python
stoch_entry = stoch_cross & (close > kama) & vol_confirm
cci_entry = cci_bounce & (close > kama) & vol_confirm
```

## Exit Design Principles

A good exit system matters more than entries. Design multiple exit types:

| Type | Description | Example |
|------|-------------|---------|
| Trend reversal | Trend confirms bearish | EMA bearish + 3-bar below KAMA |
| Profit protect | Lock gains after rally | Extended >13% → break TEMA |
| Overbought | RSI mean reversion | RSI was >80, now <70 |
| Volatility danger | Vol spike + decline | NATR > avg*1.25 + falling |
| Event exit | External risk | VIX > 28 |
| Time exit | Extended streak ending | Streak > 90 → break KAMA |

## Short System

Shorting requires stricter filters (markets have long bias):

```python
short_entries = trend_short & (minus_di > plus_di) & (adx > 22) & vol_confirm & ~recovery_mode
```

## Strategy Complexity Guide

| Stage | Lines | Indicators | Description |
|-------|-------|-----------|-------------|
| Basic | 30~50 | 2~3 | EMA cross + simple exit |
| Advanced | 80~120 | 5~8 | Multi-layer entry + exits |
| Complete | 150~200 | 10~15 | 5-layer + adaptive |
| Over-complex | >250 | >20 | Likely overfit, simplify |

## References

- **Indicator functions**: https://ta-lib.org/functions/
- **pandas_ta**: https://github.com/twopirllc/pandas_ta
- [Backtest Engine API](backtesting-reference.en.md)
- [Evaluation Metrics](metrics-reference.en.md)
- [Optimization Methods](optimization-reference.en.md)
