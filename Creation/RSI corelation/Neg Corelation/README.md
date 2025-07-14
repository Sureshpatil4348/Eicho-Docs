# Backtest Analysis Tools

This repository contains Python scripts for analyzing forex pair correlation backtest results. The scripts analyze various metrics including Sharpe ratio, profit, volatility, trade duration, win rates, and more.

## Available Scripts

### 1. Basic Analysis (`analyze_backtest.py`)

This script performs a basic analysis of all backtest CSV files in the directory and generates a text report.

```bash
python analyze_backtest.py
```

Output:
- `backtest_analysis_results.csv`: CSV file with all analysis results
- `backtest_analysis_report.txt`: Text report with detailed analysis

### 2. Visual Analysis (`analyze_backtest_with_charts.py`)

This script extends the basic analysis by generating charts and visualizations.

```bash
python analyze_backtest_with_charts.py
```

Output:
- Same as basic analysis
- Creates a `charts` directory with various visualizations

### 3. Advanced Analysis (`analyze_backtest_advanced.py`)

This script offers advanced filtering options and generates an HTML report with interactive features.

```bash
python analyze_backtest_advanced.py [options]
```

Options:
- `--min-sharpe FLOAT`: Minimum Sharpe ratio for filtering strategies
- `--min-profit FLOAT`: Minimum total profit for filtering strategies
- `--max-drawdown FLOAT`: Maximum drawdown (negative number) for filtering
- `--min-trades INT`: Minimum number of trades
- `--min-win-rate FLOAT`: Minimum win rate (0-1)
- `--min-profit-factor FLOAT`: Minimum profit factor
- `--output FILE`: Output HTML file (default: backtest_report.html)
- `--top-n INT`: Number of top strategies to chart (default: 5)

Example:
```bash
python analyze_backtest_advanced.py --min-sharpe 3.0 --min-profit 10000 --output custom_report.html
```

Output:
- `backtest_analysis_results.csv`: CSV file with filtered analysis results
- `backtest_report.html` (or custom name): HTML report with interactive charts and tables
- Charts directory with various visualizations

## Metrics Explained

- **Sharpe Ratio**: Risk-adjusted return (higher is better, calculated with 0% risk-free rate)
- **Volatility**: Standard deviation of returns (annualized)
- **Win Rate**: Proportion of winning trades
- **Profit Factor**: Gross profit / gross loss (higher is better)
- **Max Drawdown**: Maximum loss from a previous peak
- **Avg Trade Duration**: Average time trades were open

## Requirements

- Python 3.6+
- pandas
- numpy
- matplotlib
- jinja2 (for HTML reports)

## Notes

- The CSV files should be in the format `PAIR1_PAIR2_backtest_report.csv`
- The files should contain columns for Trade Type, Entry Time, Exit Time, Duration (hrs), Total P&L, etc. 