# 視覺化系統

## 產出圖表

`plot_equity.py` 產生以下圖表：

| 圖表 | 檔名 | 內容 |
|------|------|------|
| 全期回測 | `backtest_full_period.png` | 全資料直接跑策略，單段權益+回撤 |
| 連續權益 | `backtest_full.png` | IS+OOS 串接，OOS 從 IS 終值開始 |
| 樣本內 | `backtest_IS.png` | IS 單獨權益+回撤 |
| 樣本外 | `backtest_OOS.png` | OOS 單獨權益+回撤 |
| 合併摘要 | `backtest_result.png` | 權益+回撤+績效表三合一 |

## 圖表結構

### 權益曲線 + 回撤（標準兩軸圖）
```
┌────────────────────────────────────┐
│  權益曲線 (Portfolio Value)          │  ← 上方 3/4
│  IS (藍) + OOS (紅) + 分割線 (灰)    │
├────────────────────────────────────┤
│  回撤 (Drawdown %)                  │  ← 下方 1/4
│  IS DD (藍) + OOS DD (紅)            │
└────────────────────────────────────┘
```

### 績效摘要表
```
┌────────┬─────────────┬──────────────┐
│  指標   │  樣本內 (IS)  │  樣本外 (OOS) │
├────────┼─────────────┼──────────────┤
│  報酬率  │  +45.23%    │  +18.56%     │
│  Sharpe │  1.2345     │  0.8765      │
│  ...    │  ...        │  ...         │
└────────┴─────────────┴──────────────┘
```

## 圖表標題格式

```python
# 全期
f'全期回測 {period} | 報酬{ret:+.1f}% | 夏普{sharpe:.2f} | 回撤{mdd:.1f}% | 勝率{wr:.0f}% | {trades}筆 | 未創高{nh}天'

# 連續
f'連續權益曲線 {period} | 穩健度 {score} | IS未創高{nh_is}天 | OOS未創高{nh_oos}天'

# 合併
f'策略回測 — 穩健度: {score} | 最大未創高: IS {nh_is}天 / OOS {nh_oos}天'
```

## NH 計算

```python
def calc_max_no_new_high_days(eq):
    """計算權益曲線最大未創新高天數"""
    running_max = eq.cummax()
    underwater = eq < running_max
    if not underwater.any():
        return 0
    groups = (~underwater).cumsum()
    max_days = 0
    for g, sub in underwater.groupby(groups):
        if sub.any() and sub.sum() > 0:
            start_date = sub[sub].index[0].date()
            end_date = sub[sub].index[-1].date()
            days = (end_date - start_date).days
            max_days = max(max_days, days)
    return max_days
```

## 使用方式

```bash
# 產生所有圖表
python plot_equity.py

# 只算 NH
python calc_nh.py
# 輸出:
# nh_max_days: 145
# nh_period: 2023-05-15 ~ 2023-10-07
# nh_2nd: 98 days (...)
# nh_3rd: 67 days (...)
# total_return: 1687.3%
# max_drawdown: 8.5%
```

## matplotlib 中文設定

```python
import matplotlib
matplotlib.use('Agg')  # 無 GUI 環境
import matplotlib.pyplot as plt
plt.rcParams['font.sans-serif'] = ['Microsoft JhengHei', 'Microsoft YaHei', 'SimHei', 'Arial']
plt.rcParams['axes.unicode_minus'] = False
```

## 圖表配色

| 元素 | 色碼 | 用途 |
|------|------|------|
| IS 權益 | `#2196F3` (藍) | 樣本內曲線 |
| OOS 權益 | `#FF5722` (紅) | 樣本外曲線 |
| 全期權益 | `#4CAF50` (綠) | 全期曲線 |
| 分割線 | `gray --` | IS/OOS 分界 |
| 表頭 | `#E3F2FD` | 績效表表頭背景 |

## 自訂圖表

如需在圖上加額外資訊（例如交易點位、指標疊圖）：

```python
# 在權益曲線上標記交易進出場
ax1.scatter(entry_dates, entry_prices, marker='^', color='g', s=50)
ax1.scatter(exit_dates, exit_prices, marker='v', color='r', s=50)

# 在子圖加指標
ax_ind = fig.add_subplot(4, 1, 3)
ax_ind.plot(rsi.index, rsi.values, color='purple', label='RSI')
ax_ind.axhline(70, color='r', linestyle='--', alpha=0.5)
ax_ind.axhline(30, color='g', linestyle='--', alpha=0.5)
```

## 相關參考

- [回測引擎 API](backtesting-reference.md) — Portfolio 物件方法
- [評估指標](metrics-reference.md) — 圖表中顯示的指標定義
