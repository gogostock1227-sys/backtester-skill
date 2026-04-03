# 回測引擎 API (prepare.py)

> `prepare.py` 是固定基礎設施，**不可修改**。Strategy 只需 import 並呼叫。

## 資料載入

### `load_data() -> DataFrame`

載入 OHLCV 資料，回傳標準化 DataFrame。

```python
from prepare import load_data
df = load_data()
# columns: open, high, low, close, volume
# index: datetime (頻率取決於資料)
```

**適配不同標的/頻率**時修改此函數：
```python
# 範例: 從 CSV 載入 5 分 K
DATA_FILE = "my_stock_5min.csv"
def load_data():
    df = pd.read_csv(DATA_FILE, parse_dates=['datetime'], index_col='datetime')
    return df[['open', 'high', 'low', 'close', 'volume']].astype(float)
```

### `split_data(df, train_ratio=0.7) -> (df_is, df_oos)`

時間序列切割，**非隨機取樣**。防止未來資訊洩漏 (look-ahead bias)。

```python
df_is, df_oos = split_data(df)       # 70/30
df_is, df_oos = split_data(df, 0.6)  # 60/40
```

## 回測引擎

### `run_backtest(close, entries, exits, short_entries=None, short_exits=None, init_cash=1_000_000) -> Portfolio`

基於 vectorbt `Portfolio.from_signals()` 包裝。

| 參數 | 型別 | 說明 |
|------|------|------|
| `close` | Series | 收盤價 |
| `entries` | Series[bool] | 做多進場 |
| `exits` | Series[bool] | 做多出場 |
| `short_entries` | Series[bool] | 做空進場（可選） |
| `short_exits` | Series[bool] | 做空出場（可選） |
| `init_cash` | float | 初始資金 |

**交易成本（依標的調整）：**

```python
# === 範例: 台灣個股期貨 ===
TOTAL_FEE_RATE = 0.00003   # 期交稅 + 手續費
SLIPPAGE = 0.001            # 0.1%
FREQ = '60min'

# === 範例: 台股現股 ===
TOTAL_FEE_RATE = 0.004     # 券商手續費 0.1425% + 證交稅 0.3%
SLIPPAGE = 0.001
FREQ = 'D'

# === 範例: 美股 ===
TOTAL_FEE_RATE = 0.0       # 零手續費券商
SLIPPAGE = 0.0005
FREQ = 'D'

# === 範例: 加密貨幣 ===
TOTAL_FEE_RATE = 0.001     # Maker 0.1%
SLIPPAGE = 0.002
FREQ = '15min'
```

### Portfolio 常用方法

```python
pf = run_backtest(close, entries, exits)

pf.value()                     # 權益曲線 Series
pf.total_return()              # 總報酬 (0.15 = 15%)
pf.sharpe_ratio()              # 年化夏普
pf.sortino_ratio()             # 年化索提諾
pf.max_drawdown()              # 最大回撤 (負值)
pf.drawdown()                  # 回撤序列
pf.trades.records_readable     # 交易明細 (含 PnL)
```

## 評估

### `evaluate(pf, label="") -> dict`

| 欄位 | 說明 | 健康範圍 |
|------|------|----------|
| `total_return_pct` | 總報酬 % | 視頻率/期間 |
| `sharpe` | 夏普比率 | >0.8 |
| `sortino` | 索提諾比率 | >1.0 |
| `max_drawdown_pct` | 最大回撤 % (正值) | <20% |
| `calmar` | return / drawdown | >1.0 |
| `win_rate_pct` | 勝率 % | 40~60% |
| `num_trades` | 交易次數 | 足夠取樣 |
| `avg_pnl` | 平均損益 | 正值 |
| `profit_factor` | 總獲利 / 總虧損 | >1.5 |

### `robustness_score(is_metrics, oos_metrics) -> float`

穩健度評分 (0~100)，**最終排名依據**。

| 權重 | 指標 | 上限 | 意義 |
|------|------|------|------|
| 25% | Sharpe 平均 | 2.0 | 風險調整報酬 |
| 25% | IS/OOS 一致性 | — | 防過擬合（OOS>0 額外 +0.2） |
| 20% | 低回撤 | 30% | 風險控制 |
| 15% | Sortino 平均 | 3.0 | 下行風險 |
| 15% | Calmar 平均 | 3.0 | 報酬/回撤比 |

## 主流程

### `run_experiment(strategy_func)`

載入 → 切割 → IS/OOS 分別跑策略 → 分別回測 → 評估 → 印出標準化結果。

```
---
robustness_score: 45.2
is_return_pct: 15.3
oos_return_pct: 8.7
...
elapsed_seconds: 3.2
```

## 訊號設計模式

### 交叉 (Crossover / Crossunder)
```python
golden = (fast > slow) & (fast.shift(1) <= slow.shift(1))
death  = (fast < slow) & (fast.shift(1) >= slow.shift(1))
```

### 連續 N 根確認
```python
cond = close < threshold
cond_3 = cond & cond.shift(1) & cond.shift(2)
```

### Streak 計數
```python
flag = (close > ema).astype(int)
streak = flag.groupby((~flag.astype(bool)).cumsum()).cumsum()
extended = streak > 120
```

### 多訊號組合
```python
entries = (sig_a | sig_b | sig_c) & filter_1 & filter_2 & ~suppress
exits   = exit_a | exit_b | exit_c
```

## 相關參考

- [策略架構](strategy-reference.md)
- [評估指標](metrics-reference.md)
- [優化方法](optimization-reference.md)
