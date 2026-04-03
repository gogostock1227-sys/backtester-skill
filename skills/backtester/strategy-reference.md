# 策略架構 — 訊號設計模式

> 指標計算詳見 [TA-Lib 函數文件](https://ta-lib.org/functions/) 和 [pandas_ta](https://github.com/twopirllc/pandas_ta)。
> 本文件聚焦於**如何組合指標成為策略**，而非指標本身的用法。

## 五層訊號架構

一個完整策略包含進場、過濾、出場三大塊，建議分為 5 層：

```
Layer 1: 趨勢判斷      → 決定方向 (均線/通道/MACD)
Layer 2: 精確進場      → 找好的入場點 (震盪指標/突破)
Layer 3: 特殊情境      → 崩跌反彈 / 極端行情
Layer 4: 外部因子      → VIX / 大盤 / 其他市場
Layer 5: 過濾與確認    → 量能 / 崩跌保護 / 過熱抑制
```

每層獨立設計，最後用布林邏輯組合。

## 訊號設計模式

### 交叉 (Crossover / Crossunder)

最基礎的訊號類型。兩條線交叉。

```python
# 黃金交叉: fast 從下穿上 slow
golden = (fast > slow) & (fast.shift(1) <= slow.shift(1))
# 死亡交叉
death = (fast < slow) & (fast.shift(1) >= slow.shift(1))
```

### 超賣/超買反彈

震盪指標從極值區域恢復。

```python
# RSI 超賣反彈
entry = (rsi > 30) & (rsi.shift(1) <= 30)
# CCI 深度超賣恢復
entry = (cci > -50) & (cci.shift(1) <= -80)
# MFI 需要滑窗確認曾達極低
entry = (mfi > 25) & (mfi.shift(1) <= 25) & (mfi.rolling(10).min() < 18)
```

### 連續 N 根確認

減少雜訊，確認訊號持續。

```python
cond = close < threshold
cond_3 = cond & cond.shift(1) & cond.shift(2)  # 連續 3 根
```

### Streak 計數

計算條件連續成立的長度。

```python
flag = (close > ema).astype(int)
streak = flag.groupby((~flag.astype(bool)).cumsum()).cumsum()
extended = streak > 120  # 連續 120 根以上
```

### 突破

價格突破前高。

```python
donchian_high = high.rolling(N).max()
breakout = (close > donchian_high.shift(1)) & (close.shift(1) <= donchian_high.shift(2))
```

### 崩跌偵測與反彈

```python
bounce = (close > close.shift(2)) & (close > tema)
crash = (close.rolling(25).min() / close.rolling(25).max() - 1) < -0.15
recovery = crash & bounce & vol_confirm
```

### 自適應邏輯 (ADX/VIX 切換)

根據市場狀態切換參數。

```python
# 強趨勢用慢參數，弱趨勢用快參數
kama_exit = np.where(adx > 33, kama_slow, kama_fast)
# VIX 高時收緊出場，VIX 低時放寬
adaptive_gap = np.where(vix < 18, 0.01, 0.0)
```

## 組合邏輯

### 多訊號 OR 入場 + AND 過濾

```python
# 入場: 任一訊號觸發
entries = (trend_signal | osc_signal | recovery_signal) & filter_1 & filter_2 & ~suppress

# 出場: 任一條件觸發即離場
exits = exit_fast | exit_patient | exit_protect | exit_danger
```

### 常用過濾器

```python
vol_confirm = volume > volume.rolling(20).mean() * 0.65     # 量能
not_crashing = (close - high.rolling(100).max()) / high.rolling(100).max() > -0.06  # 崩跌保護
bullish_bar = close > open                                    # 收陽確認
obv_rising = obv > obv.rolling(20).mean()                   # OBV 確認
```

### 震盪入場加趨勢過濾

震盪指標（RSI/StochRSI/CCI/MFI）單獨使用雜訊多，必須加趨勢過濾：

```python
# 每個震盪訊號都要 close > kama 或 close > ema_m
stoch_entry = stoch_cross & (close > kama) & vol_confirm
cci_entry = cci_bounce & (close > kama) & vol_confirm
```

## 出場設計原則

好的出場系統比入場更重要。建議設計多種出場條件：

| 類型 | 說明 | 範例 |
|------|------|------|
| 趨勢反轉出場 | 趨勢確認翻空 | EMA 空 + 3 根 below KAMA |
| 利潤保護 | 大漲後鎖利 | 延伸 >13% → 跌破 TEMA |
| 超買出場 | RSI 超買回落 | RSI 曾>80 現<70 |
| 波動危險 | 波動率突增 | NATR > avg*1.25 + 下跌 |
| 事件出場 | 外部風險 | VIX > 28 |
| 時間出場 | 連續太久 | Streak > 90 → 跌破 KAMA |

## 做空系統

做空比做多需要更嚴格的過濾（市場天生偏多）：

```python
# 做空需要: 趨勢訊號 + DI 確認 + ADX 強度 + 量能 + 非恢復期
short_entries = trend_short & (minus_di > plus_di) & (adx > 22) & vol_confirm & ~recovery_mode
```

## 策略複雜度指引

| 策略階段 | 行數 | 指標數 | 說明 |
|----------|------|--------|------|
| 基礎版 | 30~50 行 | 2~3 | EMA 交叉 + 簡單出場 |
| 進階版 | 80~120 行 | 5~8 | 多層入場 + 多重出場 |
| 完整版 | 150~200 行 | 10~15 | 5 層架構 + 自適應 |
| 過度複雜 | >250 行 | >20 | 可能過擬合，需要精簡 |

## 相關參考

- **指標函數**: https://ta-lib.org/functions/
- **pandas_ta**: https://github.com/twopirllc/pandas_ta
- [回測引擎 API](backtesting-reference.md) — 如何執行回測
- [評估指標](metrics-reference.md) — 如何衡量策略品質
- [優化方法](optimization-reference.md) — 如何系統性改進
