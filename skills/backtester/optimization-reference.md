# 優化方法論

## 系統性實驗流程

### Autoresearch 迴圈

```
LOOP:
  1. 修改 strategy.py
  2. git commit
  3. python strategy.py > run.log 2>&1
  4. grep 關鍵指標
  5. 記錄到 results.tsv
  6. score 提升 → 保留 commit
     score 退步 → git reset 回上一個 commit
  7. 重複
```

### 分支管理

每次實驗在專屬分支：`autoresearch/<tag>`（例如 `autoresearch/apr03`）

### 結果記錄 (results.tsv)

```
commit	robustness_score	oos_return_pct	oos_sharpe	oos_max_drawdown_pct	status	description
a1b2c3d	45.2	8.7	0.88	15.7	keep	baseline EMA 16/40
b2c3d4e	52.1	12.3	1.12	10.2	keep	+RSI filter
c3d4e5f	38.5	-5.2	-0.34	22.1	discard	MACD (OOS weak)
d4e5f6g	0.0	0.0	0.0	0.0	crash	index error
```

## 四階段探索法

### Phase 1 — 廣度掃描

快速測每個策略類別的「最經典」變體：

| 類別 | 經典策略 | 目的 |
|------|----------|------|
| 趨勢跟蹤 | SMA 10/30 → EMA 8/21 → MACD 12/26/9 | 找最適方向 |
| 動量 | ROC 10 → MOM 14 → CMO 14 | 動量有效性 |
| 突破 | Donchian 20 → BB Breakout 20/2 | 突破有效性 |
| 均值回歸 | RSI 14/30/70 → BB MeanRev 20/2 | 回歸有效性 |
| 混合 | EMA + RSI → HL + StochRSI | 基礎組合 |

**每個實驗 10~30 秒，一小時可跑 60+ 個。**

### Phase 2 — 深度優化

對 Phase 1 中 score 最高的 2~3 類別密集調參：

```python
# 範例: EMA 週期掃描
for fast in [5, 8, 12, 16, 20]:
    for slow in [21, 30, 40, 50, 60]:
        test(fast, slow)
```

加入過濾條件實驗：
- ADX > 20 (趨勢強度過濾)
- 量能 > 1.5x MA
- RSI 50~70 區間
- OBV 上升

### Phase 3 — 組合與強化

- 趨勢確認 + 動量入場
- 多重出場條件
- 崩跌保護 / 過熱抑制
- 外部因子（VIX、大盤）

### Phase 4 — 精細微調

- Grid Search 自動化
- 單參數敏感度分析
- Walk-Forward 驗證（可選）

## Grid Search 範本

```python
from itertools import product
import time

def test_params(param_a, param_b, param_c):
    """測試一組參數，回傳 (nh, return, mdd)"""
    # ... 建構策略 ...
    pf = run_backtest(close, entries, exits)
    nh = calc_nh(pf)
    ret = pf.total_return() * 100
    mdd = abs(pf.max_drawdown() * 100)
    return nh, ret, mdd

# 定義搜索空間
grid = {
    'param_a': [10, 14, 18],
    'param_b': [30, 35, 40],
    'param_c': [-0.04, -0.06, -0.08],
}

results = []
for a, b, c in product(grid['param_a'], grid['param_b'], grid['param_c']):
    nh, ret, mdd = test_params(a, b, c)
    results.append({'a': a, 'b': b, 'c': c, 'nh': nh, 'return': ret, 'mdd': mdd})

# 排序: NH 優先, 再看報酬
df = pd.DataFrame(results).sort_values(['nh', 'return'], ascending=[True, False])
print(df.head(10))

# 或: 篩選 NH < 150 再排報酬
good = df[df['nh'] <= 150].sort_values('return', ascending=False)
```

### 搜索策略

1. **粗掃 (3^4 = 81 組)**：固定大部分參數，只掃 4 個關鍵參數
2. **細掃 (窄範圍)**：在最佳區域附近縮小步長
3. **交叉驗證**：最佳參數在 IS 和 OOS 上都要好

## 多階段實驗範本

```python
experiments = [
    # Phase 1: 指標選擇
    {'name': 'MFI Fine Tune', 'params': {'period': [10,14,18], 'buy': [15,20,25]}},
    {'name': 'RSI MeanRev',   'params': {'period': [6,10,14], 'oversold': [20,25,30]}},

    # Phase 2: 組合
    {'name': 'MFI + RSI',    'params': {'mfi_buy': [15,20], 'rsi_os': [25,30]}},

    # Phase 3: 風控
    {'name': '+ StopLoss',   'params': {'sl': [0.02, 0.03, 0.05]}},
    {'name': '+ TrailStop',  'params': {'ts': [0.01, 0.015, 0.02]}},
]

for exp in experiments:
    print(f"\n=== {exp['name']} ===")
    # ... grid search within experiment ...
    # 每個實驗排名, 取 Top 3 進入下一階段
```

## 優化陷阱

### 1. 過擬合

**症狀**: IS 報酬極高，OOS 崩潰
**對策**: robustness_score 的一致性權重自動懲罰

### 2. 參數島嶼

**症狀**: 只有某個特定參數組合好，鄰近參數都差
**對策**: 好的參數應該有「高原」— 附近參數 score 相近

### 3. 過度擬合特定行情

**症狀**: 某個大漲段貢獻了 80% 報酬
**對策**: 看 NH 和回撤均勻度，不只看總報酬

### 4. Hack 堆積

**症狀**: 策略越來越複雜，score 只微增
**對策**: 簡潔原則 — 刪掉條件後 score 不變就刪

## 實驗決策樹

```
score 提升 > 2 分？
├── YES → 保留 commit, 繼續優化
├── 提升 0~2 分
│   ├── 策略更簡潔？ → 保留
│   └── 更複雜？ → 考慮捨棄
└── NO (退步)
    ├── 退步 < 2 分
    │   ├── 嘗試微調？ → 再試一次
    │   └── 方向不對？ → reset, 換方向
    └── 退步 > 5 分 → reset, 方向完全錯誤
```

## 相關參考

- [回測引擎 API](backtesting-reference.md) — 如何執行回測
- [評估指標](metrics-reference.md) — 如何解讀結果
- [策略架構](strategy-reference.md) — 指標和訊號選擇
