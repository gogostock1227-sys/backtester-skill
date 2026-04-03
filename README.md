# Backtester Skill

通用系統化交易策略回測框架，適用於 Claude Code / Codex / Cursor / Windsurf / Gemini CLI。

Universal systematic trading strategy backtesting framework for AI CLI tools.

## Install

```bash
curl -sSf https://raw.githubusercontent.com/gogostock1227-sys/backtester-skill/main/install.sh | sh
```

## What's included

- **Backtest Engine API** — vectorbt-based IS/OOS backtest with robustness scoring
- **Strategy Architecture** — Multi-layer signal design patterns (trend + oscillator + crash recovery)
- **Evaluation Metrics** — robustness_score, NH (No New High), Sharpe, Sortino, Calmar
- **Optimization Methods** — Grid search, autoresearch loop, 4-phase exploration
- **Visualization** — Equity curves, drawdown charts, performance summary tables

## Supports

- **Any asset**: Stocks, futures, ETFs, crypto
- **Any timeframe**: 1-min, 5-min, 15-min, 60-min, daily, weekly
- **Any market**: Taiwan, US, China, forex, crypto

## Languages

- 中文版: `SKILL.md` + all `*-reference.md`
- English: `SKILL.en.md` + all `*-reference.en.md`

## Dependencies

- Python 3.10+
- [TA-Lib](https://ta-lib.org/install/) (C library + Python wrapper)
- vectorbt, pandas_ta, pandas, numpy, matplotlib
