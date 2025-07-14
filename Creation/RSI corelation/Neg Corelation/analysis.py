import pandas as pd
import numpy as np
import os
import glob
import ast
import seaborn as sns
import matplotlib.pyplot as plt

def analyze_backtest_file(filepath):
    """
    Analyzes a single backtest report file.
    """
    try:
        df = pd.read_csv(filepath)
    except Exception as e:
        return {"pair": os.path.basename(filepath), "error": str(e)}

    # Data cleaning and preparation
    if 'Entry Time' not in df.columns or 'Exit Time' not in df.columns:
        return {"pair": os.path.basename(filepath), "error": "Missing Entry Time or Exit Time columns"}
    
    df['Entry Time'] = pd.to_datetime(df['Entry Time'])
    df['Exit Time'] = pd.to_datetime(df['Exit Time'])
    df['Duration'] = df['Exit Time'] - df['Entry Time']
    
    if 'Total P&L' not in df.columns:
        return {"pair": os.path.basename(filepath), "error": "Missing Total P&L column"}

    # Calculations
    total_trades = len(df)
    if total_trades == 0:
        return {"pair": os.path.basename(filepath), "error": "No trades found"}
        
    total_profit = df['Total P&L'].sum()
    
    # Volatility and Sharpe Ratio
    # Assuming 'Total P&L' column represents the return of each trade
    returns = df['Total P&L']
    volatility = returns.std()
    # Sharpe Ratio with 0 risk-free rate
    sharpe_ratio = returns.mean() / volatility if volatility != 0 else 0
    
    avg_trade_duration = df['Duration'].mean()
    
    profit_per_year = df.groupby(df['Exit Time'].dt.year)['Total P&L'].sum().to_dict()

    buy_trades = df[df['Trade Type'] == 'LONG']
    sell_trades = df[df['Trade Type'] == 'SHORT']
    
    total_buy_trades = len(buy_trades)
    total_sell_trades = len(sell_trades)
    
    profit_loss_by_pair = total_profit # Since one file is one pair
    
    max_loss = df['Total P&L'].min() if not df[df['Total P&L'] < 0].empty else 0

    winning_trades = df[df['Total P&L'] > 0]['Total P&L']
    losing_trades = df[df['Total P&L'] < 0]['Total P&L']
    
    avg_win = winning_trades.mean() if not winning_trades.empty else 0
    avg_loss = losing_trades.mean() if not losing_trades.empty else 0

    return {
        "pair": os.path.basename(filepath).replace('_backtest_report.csv', ''),
        "sharpe_ratio": sharpe_ratio,
        "volatility": volatility,
        "avg_trade_duration": str(avg_trade_duration),
        "total_trades": total_trades,
        "total_profit": total_profit,
        "profit_per_year": profit_per_year,
        "total_buy_trades": total_buy_trades,
        "total_sell_trades": total_sell_trades,
        "profit_loss_by_pair": profit_loss_by_pair,
        "max_loss": max_loss,
        "avg_win": avg_win,
        "avg_loss": avg_loss,
    }

def analyze_performance_correlation():
    """
    Analyzes the performance correlation of pairs from high_sharpe_ratio_pairs.csv.
    """
    try:
        df = pd.read_csv('high_sharpe_ratio_pairs.csv')
    except FileNotFoundError:
        print("Error: 'high_sharpe_ratio_pairs.csv' not found.")
        print("Please run the initial analysis first to generate the required files.")
        return

    # The 'profit_per_year' is a string representation of a dict.
    # We need to parse it.
    df['profit_per_year'] = df['profit_per_year'].apply(ast.literal_eval)

    # Create a new DataFrame with yearly profits
    yearly_profits = {}
    all_years = set()
    for index, row in df.iterrows():
        pair = row['pair']
        profits = row['profit_per_year']
        yearly_profits[pair] = profits
        all_years.update(profits.keys())
    
    sorted_years = sorted(list(all_years))

    profit_df = pd.DataFrame.from_dict(yearly_profits, orient='index', columns=sorted_years)
    profit_df = profit_df.fillna(0)

    # Calculate the correlation matrix
    correlation_matrix = profit_df.T.corr()

    print("--- Performance Correlation Matrix ---")
    print(correlation_matrix)

    # Generate and save a heatmap
    plt.figure(figsize=(12, 10))
    sns.heatmap(correlation_matrix, annot=True, cmap='coolwarm', fmt=".2f", annot_kws={"size": 8})
    plt.title('Yearly Profit Performance Correlation of Currency Pairs')
    plt.tight_layout()
    plt.savefig('performance_correlation_heatmap.png')
    print("\nCorrelation heatmap saved to 'performance_correlation_heatmap.png'")

def count_correlations():
    """
    Counts the number of positively and negatively correlated pairs.
    """
    try:
        df = pd.read_csv('high_sharpe_ratio_pairs.csv')
    except FileNotFoundError:
        print("Error: 'high_sharpe_ratio_pairs.csv' not found.")
        return

    df['profit_per_year'] = df['profit_per_year'].apply(ast.literal_eval)

    yearly_profits = {}
    all_years = set()
    for index, row in df.iterrows():
        pair = row['pair']
        profits = row['profit_per_year']
        yearly_profits[pair] = profits
        all_years.update(profits.keys())
    
    sorted_years = sorted(list(all_years))

    profit_df = pd.DataFrame.from_dict(yearly_profits, orient='index', columns=sorted_years)
    profit_df = profit_df.fillna(0)

    correlation_matrix = profit_df.T.corr()

    # To avoid double counting, we'll only look at the upper triangle of the matrix
    upper_triangle = correlation_matrix.where(np.triu(np.ones(correlation_matrix.shape), k=1).astype(bool))
    
    positive_correlations = (upper_triangle > 0).sum().sum()
    negative_correlations = (upper_triangle < 0).sum().sum()

    print("\n--- Correlation Counts ---")
    print(f"Number of positively correlated pairs: {positive_correlations}")
    print(f"Number of negatively correlated pairs: {negative_correlations}")

def main():
    """
    Main function to analyze all backtest reports.
    """
    csv_files = glob.glob('*_backtest_report.csv')
    all_results = []

    for file in csv_files:
        result = analyze_backtest_file(file)
        all_results.append(result)

    # Create a DataFrame from the results
    results_df = pd.DataFrame(all_results)
    
    # Save to a new CSV file
    results_df.to_csv('backtest_analysis_results.csv', index=False)
    
    # Also save to a text file for better readability of nested data
    with open('backtest_analysis_report.txt', 'w') as f:
        for result in all_results:
            f.write("--- Analysis for: {} ---\n".format(result.get('pair', 'N/A')))
            if 'error' in result:
                f.write("Error: {}\n".format(result['error']))
            else:
                for key, value in result.items():
                    if key == 'profit_per_year':
                        f.write("Profit Per Year:\n")
                        if isinstance(value, dict):
                            for year, profit in value.items():
                                f.write(f"  {year}: {profit:.2f}\n")
                    else:
                        f.write(f"{key.replace('_', ' ').title()}: {value}\n")
            f.write("\n")
            
    print("Analysis complete. Results saved to 'backtest_analysis_results.csv' and 'backtest_analysis_report.txt'")

if __name__ == '__main__':
    # main()
    # analyze_performance_correlation()
    count_correlations() 