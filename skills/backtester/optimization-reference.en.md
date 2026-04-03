# Optimization Methodology

## Systematic Experiment Loop

### Autoresearch Cycle

```
LOOP:
  1. Edit strategy.py
  2. git commit
  3. python strategy.py > run.log 2>&1
  4. grep key metrics
  5. Log to results.tsv
  6. Score improved → keep commit
     Score regressed → git reset to previous
  7. Repeat
```

### Branch Management

Each experiment session on a dedicated branch: `autoresearch/<tag>` (e.g., `autoresearch/apr03`)

### Results Log (results.tsv)

```
commit	robustness_score	oos_return_pct	oos_sharpe	oos_max_drawdown_pct	status	description
a1b2c3d	45.2	8.7	0.88	15.7	keep	baseline EMA 16/40
b2c3d4e	52.1	12.3	1.12	10.2	keep	+RSI filter
c3d4e5f	38.5	-5.2	-0.34	22.1	discard	MACD (OOS weak)
d4e5f6g	0.0	0.0	0.0	0.0	crash	index error
```

## Four-Phase Exploration

### Phase 1 — Breadth Scan

Quickly test the "classic" variant of each strategy category:

| Category | Classic Strategies | Goal |
|----------|--------------------|------|
| Trend | SMA 10/30 → EMA 8/21 → MACD 12/26/9 | Find best direction |
| Momentum | ROC 10 → MOM 14 → CMO 14 | Momentum effectiveness |
| Breakout | Donchian 20 → BB Breakout 20/2 | Breakout effectiveness |
| Mean Rev | RSI 14/30/70 → BB MeanRev 20/2 | Reversion effectiveness |
| Hybrid | EMA + RSI → HL + StochRSI | Basic combos |

**Each experiment takes 10~30s. 60+ experiments per hour.**

### Phase 2 — Deep Optimization

Intensive parameter tuning on the top 2~3 categories from Phase 1:

```python
for fast in [5, 8, 12, 16, 20]:
    for slow in [21, 30, 40, 50, 60]:
        test(fast, slow)
```

Add filter experiments: ADX > 20, volume > 1.5x MA, RSI band, OBV rising.

### Phase 3 — Combination & Hardening

- Trend confirmation + momentum entry
- Multiple exit conditions
- Crash protection / overheating suppression
- External factors (VIX, market index)

### Phase 4 — Fine Tuning

- Automated grid search
- Single-parameter sensitivity analysis
- Walk-forward validation (optional)

## Grid Search Template

```python
from itertools import product

def test_params(param_a, param_b, param_c):
    """Test one parameter combo, return (nh, return, mdd)"""
    # ... build strategy ...
    pf = run_backtest(close, entries, exits)
    nh = calc_nh(pf)
    ret = pf.total_return() * 100
    mdd = abs(pf.max_drawdown() * 100)
    return nh, ret, mdd

grid = {
    'param_a': [10, 14, 18],
    'param_b': [30, 35, 40],
    'param_c': [-0.04, -0.06, -0.08],
}

results = []
for a, b, c in product(grid['param_a'], grid['param_b'], grid['param_c']):
    nh, ret, mdd = test_params(a, b, c)
    results.append({'a': a, 'b': b, 'c': c, 'nh': nh, 'return': ret, 'mdd': mdd})

# Sort: NH first, then return
df = pd.DataFrame(results).sort_values(['nh', 'return'], ascending=[True, False])

# Or: filter NH < 150 then sort by return
good = df[df['nh'] <= 150].sort_values('return', ascending=False)
```

### Search Strategy

1. **Coarse scan (3^4 = 81 combos)**: Fix most params, sweep 4 key ones
2. **Fine scan (narrow range)**: Tighten step size around best region
3. **Cross-validate**: Best params must work on both IS and OOS

## Optimization Pitfalls

### 1. Overfitting
**Symptom**: Extreme IS return, OOS collapse
**Defense**: robustness_score's consistency weight auto-penalizes

### 2. Parameter Islands
**Symptom**: Only one specific combo works; neighbors are all bad
**Defense**: Good params should have a "plateau" — nearby params score similarly

### 3. Regime Overfitting
**Symptom**: 80% of return comes from one big rally
**Defense**: Check NH and drawdown distribution, not just total return

### 4. Hack Accumulation
**Symptom**: Strategy complexity grows, score barely increases
**Defense**: Simplicity principle — if removing a condition doesn't hurt score, remove it

## Decision Tree

```
Score improved > 2 points?
├── YES → Keep commit, continue optimizing
├── Improved 0~2 points
│   ├── Strategy simpler? → Keep
│   └── More complex? → Consider discarding
└── NO (regressed)
    ├── Regressed < 2 points
    │   ├── Worth tweaking? → Try once more
    │   └── Wrong direction? → Reset, change approach
    └── Regressed > 5 points → Reset, completely wrong direction
```

## References

- [Backtest Engine API](backtesting-reference.en.md) — How to run backtests
- [Evaluation Metrics](metrics-reference.en.md) — How to interpret results
- [Strategy Architecture](strategy-reference.en.md) — Indicator and signal choices
