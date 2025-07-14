import pandas as pd
import numpy as np
import os

def calculate_portfolio_metrics(df, assumed_capital=100000, trading_days=252):
    """
    Calculates portfolio metrics for each pair.
    """
    metrics_list = []
    for i, row in df.iterrows():
        avg_pnl_per_trade = row['Total Profit'] / row['Total Trades']
        avg_duration_hours = row['Average Trade Duration (Hours)']
        
        if avg_duration_hours <= 0:
            continue

        avg_duration_days = avg_duration_hours / 24.0
        
        daily_return = avg_pnl_per_trade / avg_duration_days
        daily_return_pct = (daily_return / assumed_capital) * 100
        annual_return_pct = daily_return_pct * trading_days

        vol_per_trade = row['Volatility']
        daily_volatility = vol_per_trade / np.sqrt(avg_duration_days)
        daily_volatility_pct = (daily_volatility / assumed_capital) * 100
        annual_volatility_pct = daily_volatility_pct * np.sqrt(trading_days)
        
        metrics_list.append({
            'Pair': row['Pair'],
            'Daily_Return_Pct': daily_return_pct,
            'Daily_Volatility_Pct': daily_volatility_pct,
            'Annual_Return_Pct': annual_return_pct,
            'Annual_Volatility_Pct': annual_volatility_pct,
        })
    
    return pd.DataFrame(metrics_list)

def create_portfolios():
    """
    Creates and analyzes portfolios based on different weighting schemes.
    """
    try:
        analysis_report = pd.read_csv('high_sharpe_ratio_pairs.csv')
    except FileNotFoundError:
        print("high_sharpe_ratio_pairs.csv not found. Please ensure the file exists.")
        return

    pair_metrics_df = calculate_portfolio_metrics(analysis_report)
    
    data = pd.merge(analysis_report, pair_metrics_df, on='Pair')

    # --- Volatility-based Portfolio ---
    vol_portfolio = data.copy()
    vol_portfolio = vol_portfolio[vol_portfolio['Volatility'] > 0]
    vol_portfolio['Inverse Volatility'] = 1 / vol_portfolio['Volatility']
    total_inverse_vol = vol_portfolio['Inverse Volatility'].sum()
    vol_portfolio['Weight'] = (vol_portfolio['Inverse Volatility'] / total_inverse_vol) * 100

    portfolio_annual_return_vol = np.sum((vol_portfolio['Weight']/100) * (vol_portfolio['Annual_Return_Pct']/100))
    portfolio_annual_volatility_vol = np.sqrt(np.sum((vol_portfolio['Weight']/100)**2 * (vol_portfolio['Annual_Volatility_Pct']/100)**2))
    final_sharpe_vol = portfolio_annual_return_vol / portfolio_annual_volatility_vol if portfolio_annual_volatility_vol != 0 else 0
    
    vol_portfolio_df = vol_portfolio[['Pair', 'Weight', 'Daily_Return_Pct', 'Daily_Volatility_Pct', 'Annual_Return_Pct', 'Annual_Volatility_Pct']].rename(columns={'Weight': 'Weight (%)'})
    
    # --- Sharpe Ratio-based Portfolio ---
    sharpe_portfolio = data[data['Sharpe Ratio'] > 0].copy()
    total_sharpe = sharpe_portfolio['Sharpe Ratio'].sum()
    sharpe_portfolio['Weight'] = (sharpe_portfolio['Sharpe Ratio'] / total_sharpe) * 100

    portfolio_annual_return_sharpe = np.sum((sharpe_portfolio['Weight']/100) * (sharpe_portfolio['Annual_Return_Pct']/100))
    portfolio_annual_volatility_sharpe = np.sqrt(np.sum((sharpe_portfolio['Weight']/100)**2 * (sharpe_portfolio['Annual_Volatility_Pct']/100)**2))
    final_sharpe_sharpe = portfolio_annual_return_sharpe / portfolio_annual_volatility_sharpe if portfolio_annual_volatility_sharpe != 0 else 0
    
    sharpe_portfolio_df = sharpe_portfolio[['Pair', 'Weight', 'Daily_Return_Pct', 'Daily_Volatility_Pct', 'Annual_Return_Pct', 'Annual_Volatility_Pct']].rename(columns={'Weight': 'Weight (%)'})

    # --- Combine and save to CSV ---
    with open('portfolio_distributions.csv', 'w', newline='') as f:
        f.write("Volatility Based Portfolio\n")
        vol_portfolio_df.to_csv(f, index=False)
        f.write(f"Final Sharpe Ratio,{final_sharpe_vol}\n")
        f.write("\n")
        f.write("Sharpe Ratio Based Portfolio\n")
        sharpe_portfolio_df.to_csv(f, index=False)
        f.write(f"Final Sharpe Ratio,{final_sharpe_sharpe}\n")

    print("Portfolio distributions saved to 'portfolio_distributions.csv'")
    print("\nNote: Daily and Annual returns/volatility are calculated based on an assumed capital of $100,000. Portfolio Sharpe Ratio calculation assumes uncorrelated returns.")

if __name__ == '__main__':
    create_portfolios()