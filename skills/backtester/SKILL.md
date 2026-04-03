---
name: backtester
description: 通用期貨/股票回測框架。涵蓋策略開發、回測引擎、IS/OOS 驗證、robustness 評分、NH 計算、參數優化、視覺化。適用任何標的任何 K 線頻率。當使用者提到回測、策略、backtest、robustness、NH、optimize、autoresearch 時觸發。
compatibility: Python 3.10+, vectorbt, TA-Lib, pandas_ta
---

# 回測寶 — 通用系統化交易策略回測框架

## Prerequisites

**開始前依序確認：**

1. **Python 已安裝** (3.10+):

   ```bash
   python --version
   ```

2. **安裝所有依賴套件**:

   ```bash
   pip install vectorbt pandas numpy matplotlib openpyxl
   pip install pandas_ta
   ```

3. **安裝 TA-Lib** (C library + Python wrapper):

   TA-Lib 需要先裝 C 底層，再裝 Python binding。

   **Windows (推薦用預編譯 wheel):**
   ```bash
   # 從 https://github.com/cgohlke/talib-build/releases 下載對應版本 wheel
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

   **驗證安裝:**
   ```bash
   python -c "import talib; print(talib.__version__)"
   ```

   完整安裝文件: https://ta-lib.org/install/

4. **準備 OHLCV 資料檔** (Excel 或 CSV):

   ```
   欄位: date, time, open, high, low, close, volume
   格式: 按時間排序，無缺漏
   ```

## Language

**Respond in the user's language.** 使用者用中文就回中文，英文就回英文。

## 設計哲學

1. **穩健 > 報酬** — IS/OOS 一致性比單邊高報酬重要
2. **NH 優先** — 最大未創高天數是策略品質核心衡量
3. **簡潔原則** — 同等效果越簡單越好
4. **引擎不可竄改** — 回測引擎與策略分離，確保公平比較
5. **實驗可復現** — 每次變更有 git commit

## 適用範圍

| 維度 | 支援 |
|------|------|
| 標的 | 個股期貨、指數期貨、ETF、個股、加密貨幣 |
| K 線頻率 | 1 分 K、5 分 K、15 分 K、60 分 K、日 K、週 K |
| 市場 | 台股、美股、陸股、外匯、幣圈 |

只需調整 `prepare.py` 中的資料載入和交易成本。

## Quick Start

```python
# strategy.py — 最小完整範例
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

執行:
```bash
python strategy.py           # 回測 + 印出指標
python plot_equity.py        # 產生績效圖
python calc_nh.py            # 計算 NH 天數
```

## Core Workflow: 5-Step Strategy Development

### Step 1: 準備資料

修改 `prepare.py` 中的 `load_data()` 載入你的 OHLCV 資料:

```python
DATA_FILE = "my_data.xlsx"  # 或 .csv
def load_data():
    df = pd.read_excel(DATA_FILE)
    df.columns = ['date', 'time', 'open', 'high', 'low', 'close', 'volume']
    df['datetime'] = pd.to_datetime(df['date'].astype(str) + ' ' + df['time'].astype(str))
    df = df.set_index('datetime').sort_index()
    return df[['open', 'high', 'low', 'close', 'volume']].astype(float)
```

設定交易成本:
```python
TOTAL_FEE_RATE = 0.00003   # 依標的調整
SLIPPAGE = 0.001            # 滑價
```

### Step 2: 撰寫策略

只改 `strategy.py`。策略函數簽名:

```python
def strategy(df):
    """
    Input:  DataFrame (open, high, low, close, volume; index=datetime)
    Output: 2-tuple (entries, exits)
            或 4-tuple (entries, exits, short_entries, short_exits)
            每個是 bool Series
    """
    # 用 talib / pandas_ta 計算指標
    # 用布林邏輯組合進出場訊號
    return entries, exits, short_entries, short_exits
```

指標計算用 `talib` (150+ 技術指標) 和 `pandas_ta`:
- **talib 完整指標文件**: https://ta-lib.org/functions/
- **pandas_ta 文件**: https://github.com/twopirllc/pandas_ta

### Step 3: 回測

```bash
python strategy.py > run.log 2>&1
```

自動執行: 載入 → IS/OOS 切割 (70/30) → 分別回測 → 評估 → 印出標準化指標。

### Step 4: 評估

關鍵輸出:
```
robustness_score: 85.0        ← 最終排名依據 (0~100)
is_return_pct / oos_return_pct ← IS/OOS 一致最重要
```

加上 NH:
```bash
python calc_nh.py    # nh_max_days: 145
```

### Step 5: 迭代

```bash
# 改 strategy.py → commit → 跑回測 → 比較 score
git commit -m "v64: adjust KAMA exit"
python strategy.py > run.log 2>&1
grep "^robustness_score:" run.log
# score 提升就保留，退步就 reset
```

## 標準專案結構

```
project/
├── prepare.py           ← 固定基礎設施（不改）
├── strategy.py          ← 唯一可改：策略邏輯
├── plot_equity.py       ← 視覺化
├── calc_nh.py           ← NH 計算
├── optimize.py          ← Grid Search
├── program.md           ← 實驗協定
├── results.tsv          ← 實驗記錄
└── *.xlsx / *.csv       ← OHLCV 資料
```

## Reference Files

| 檔案 | 內容 |
|------|------|
| [backtesting-reference.md](backtesting-reference.md) | prepare.py API、Portfolio 用法、交易成本設定 |
| [strategy-reference.md](strategy-reference.md) | 訊號設計模式、進出場範本、組合邏輯 |
| [metrics-reference.md](metrics-reference.md) | robustness score、NH、各項績效指標公式 |
| [optimization-reference.md](optimization-reference.md) | Grid Search、autoresearch 迴圈、實驗方法論 |
| [visualization-reference.md](visualization-reference.md) | 績效圖表產生與解讀 |

## Prevent Overfitting

**核心原則：** 永遠同時看 IS 和 OOS：

```
✅ IS +50% / OOS +40%  → 穩健，保留
❌ IS +200% / OOS -50% → 過擬合，捨棄
✅ IS +20% / OOS +15%  → 低報酬但穩健，值得優化
```

## External References

- **TA-Lib 指標**: https://ta-lib.org/functions/
- **TA-Lib 安裝**: https://ta-lib.org/install/
- **pandas_ta**: https://github.com/twopirllc/pandas_ta
- **vectorbt**: https://vectorbt.dev/

---

# English version: [SKILL.en.md](SKILL.en.md)
