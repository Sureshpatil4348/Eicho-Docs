import pandas as pd
import os

def analyze_monthly_profits():
    """
    Analyzes backtest reports for high Sharpe ratio pairs to calculate
    month-on-month profit breakout and saves the results to a CSV file.
    """
    try:
        # Define file paths
        high_sharpe_pairs_file = 'high_sharpe_ratio_pairs.csv'
        output_file = 'monthly_profit_breakout.csv'
        
        # Check if the high sharpe ratio pairs file exists
        if not os.path.exists(high_sharpe_pairs_file):
            print(f"Error: '{high_sharpe_pairs_file}' not found.")
            return

        # Read the high Sharpe ratio pairs
        high_sharpe_pairs_df = pd.read_csv(high_sharpe_pairs_file)
        pairs = high_sharpe_pairs_df['pair'].unique()

        all_monthly_profits = []

        for pair in pairs:
            backtest_file = f"{pair}_backtest_report.csv"
            
            if os.path.exists(backtest_file):
                # Read the backtest report
                report_df = pd.read_csv(backtest_file)
                
                # Ensure required columns are present
                if 'Exit Time' in report_df.columns and 'Total P&L' in report_df.columns:
                    # Convert 'Exit Time' to datetime
                    report_df['Exit Time'] = pd.to_datetime(report_df['Exit Time'])
                    
                    # Create a 'YearMonth' column
                    report_df['YearMonth'] = report_df['Exit Time'].dt.to_period('M').astype(str)
                    
                    # Calculate monthly profit
                    monthly_profit = report_df.groupby('YearMonth')['Total P&L'].sum().reset_index()
                    monthly_profit.rename(columns={'Total P&L': 'MonthlyProfit'}, inplace=True)
                    monthly_profit['Pair'] = pair
                    
                    all_monthly_profits.append(monthly_profit)
                else:
                    print(f"Warning: '{backtest_file}' is missing 'Exit Time' or 'Total P&L' column.")
            else:
                print(f"Warning: Backtest report for pair '{pair}' not found at '{backtest_file}'.")

        if not all_monthly_profits:
            print("No data to process. Exiting.")
            return

        # Combine all monthly profit data
        combined_profits_df = pd.concat(all_monthly_profits, ignore_index=True)
        
        # Create a pivot table for the desired CSV format
        pivot_df = combined_profits_df.pivot_table(index='Pair', columns='YearMonth', values='MonthlyProfit', aggfunc='sum').fillna(0)
        
        # Sort columns chronologically
        pivot_df = pivot_df.reindex(sorted(pivot_df.columns), axis=1)

        # Save the pivot table to a CSV file
        pivot_df.to_csv(output_file)
        
        print(f"Successfully created '{output_file}' with month-on-month profit breakout.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    analyze_monthly_profits() 