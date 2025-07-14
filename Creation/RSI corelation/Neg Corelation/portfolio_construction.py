import pandas as pd
import numpy as np
import os

def calculate_portfolio_distribution_sharpe(df):
    """
    Calculates portfolio distribution based on Sharpe Ratio.
    Weights are proportional to the Sharpe Ratio.
    """
    total_sharpe = df['sharpe_ratio'].sum()
    df['sharpe_weight'] = df['sharpe_ratio'] / total_sharpe
    return df

def calculate_portfolio_distribution_volatility(df):
    """
    Calculates portfolio distribution based on inverse volatility.
    Weights are inversely proportional to volatility.
    """
    inverse_volatility = 1 / df['volatility']
    total_inverse_volatility = inverse_volatility.sum()
    df['volatility_weight'] = inverse_volatility / total_inverse_volatility
    return df

def calculate_portfolio_sharpe_ratio(df, weight_column):
    """
    Calculates the Sharpe ratio of a portfolio.
    This is a simplified calculation that assumes uncorrelated returns.
    """
    # Assuming risk-free rate is 0 for simplicity as it's not provided.
    # The sharpe_ratio in the CSV is likely (mean_return / volatility)
    # We can derive mean_return = sharpe_ratio * volatility
    
    if 'mean_return' not in df.columns:
        df['mean_return'] = df['sharpe_ratio'] * df['volatility']

    portfolio_return = np.sum(df[weight_column] * df['mean_return'])
    
    # Simplified portfolio volatility (assuming uncorrelated assets)
    # Portfolio Variance = sum(weight_i^2 * volatility_i^2)
    portfolio_variance = np.sum((df[weight_column]**2) * (df['volatility']**2))
    portfolio_volatility = np.sqrt(portfolio_variance)
    
    if portfolio_volatility == 0:
        return 0, 0, 0
        
    portfolio_sharpe = portfolio_return / portfolio_volatility
    return portfolio_sharpe, portfolio_return, portfolio_volatility

def add_performance_columns(df, original_df):
    """
    Adds daily and annual return and volatility percentages.
    Assumes 252 trading days in a year.
    The returns are not percentages, so we need to have a capital base to calculate that
    For now, let's assume a starting capital of 100,000 for calculation of percentages
    """
    TRADING_DAYS_PER_YEAR = 252
    CAPITAL_BASE = 100000

    # The mean_return is for the entire period of the backtest.
    # We need to find the duration of the backtest to annualize it.
    # The 'avg_trade_duration' is per trade, not for the whole period.
    # Let's assume the backtest period is roughly 4.5 years (Jan 2020 - mid 2024) from the profit_per_year column
    # This is a strong assumption.
    backtest_duration_years = 4.5 
    
    if 'mean_return' not in df.columns:
        df['mean_return'] = original_df['sharpe_ratio'] * original_df['volatility']

    # Annual Return is the mean_return averaged over the years.
    annual_return = df['mean_return'] / backtest_duration_years
    df['Annual_Return_Pct'] = (annual_return / CAPITAL_BASE) * 100
    df['Daily_Return_Pct'] = df['Annual_Return_Pct'] / TRADING_DAYS_PER_YEAR

    # The volatility in the file is for the whole period.
    # Annual Volatility = Total Volatility / sqrt(years)
    annual_volatility = original_df['volatility'] / np.sqrt(backtest_duration_years)
    df['Annual_Volatility_Pct'] = (annual_volatility / CAPITAL_BASE) * 100
    df['Daily_Volatility_Pct'] = df['Annual_Volatility_Pct'] / np.sqrt(TRADING_DAYS_PER_YEAR)
    
    return df

def main():
    # Load the data
    try:
        df = pd.read_csv('high_sharpe_ratio_pairs.csv')
    except FileNotFoundError:
        print("Error: 'high_sharpe_ratio_pairs.csv' not found.")
        return

    # Portfolio distribution based on Sharpe Ratio
    df_sharpe = df.copy()
    df_sharpe = calculate_portfolio_distribution_sharpe(df_sharpe)
    
    # Portfolio distribution based on Volatility
    df_volatility = df.copy()
    df_volatility = calculate_portfolio_distribution_volatility(df_volatility)

    # Calculate final Sharpe Ratio for each portfolio
    sharpe_portfolio_sharpe, sharpe_portfolio_return, sharpe_portfolio_volatility = calculate_portfolio_sharpe_ratio(df_sharpe, 'sharpe_weight')
    volatility_portfolio_sharpe, volatility_portfolio_return, volatility_portfolio_volatility = calculate_portfolio_sharpe_ratio(df_volatility, 'volatility_weight')

    # Print results
    print("--- Sharpe Ratio Based Portfolio ---")
    print(df_sharpe[['pair', 'sharpe_ratio', 'sharpe_weight']])
    print(f"\nPortfolio Return: {sharpe_portfolio_return:.4f}")
    print(f"Portfolio Volatility: {sharpe_portfolio_volatility:.4f}")
    print(f"Final Portfolio Sharpe Ratio: {sharpe_portfolio_sharpe:.4f}")

    print("\n--- Inverse Volatility Based Portfolio ---")
    print(df_volatility[['pair', 'volatility', 'volatility_weight']])
    print(f"\nPortfolio Return: {volatility_portfolio_return:.4f}")
    print(f"Portfolio Volatility: {volatility_portfolio_volatility:.4f}")
    print(f"Final Portfolio Sharpe Ratio: {volatility_portfolio_sharpe:.4f}")

    # --- Sharpe Ratio Portfolio Output ---
    df_sharpe_output = df_sharpe[['pair', 'sharpe_ratio', 'sharpe_weight']].copy()
    df_sharpe_output = add_performance_columns(df_sharpe_output, df_sharpe)
    df_sharpe_output.rename(columns={'sharpe_weight': 'weight_pct'}, inplace=True)
    df_sharpe_output['weight_pct'] = df_sharpe_output['weight_pct'] * 100
    df_sharpe_output['distribution_type'] = 'Sharpe Ratio Based'
    
    # Reorder columns
    sharpe_cols = ['distribution_type', 'pair', 'weight_pct', 'Daily_Return_Pct', 'Daily_Volatility_Pct', 'Annual_Return_Pct', 'Annual_Volatility_Pct', 'sharpe_ratio']
    df_sharpe_output = df_sharpe_output[sharpe_cols]

    # --- Inverse Volatility Portfolio Output ---
    df_volatility_output = df_volatility[['pair', 'volatility', 'volatility_weight']].copy()
    df_volatility_output = add_performance_columns(df_volatility_output, df_volatility)
    df_volatility_output.rename(columns={'volatility_weight': 'weight_pct'}, inplace=True)
    df_volatility_output['weight_pct'] = df_volatility_output['weight_pct'] * 100
    df_volatility_output['distribution_type'] = 'Inverse Volatility Based'

    # Reorder columns
    volatility_cols = ['distribution_type', 'pair', 'weight_pct', 'Daily_Return_Pct', 'Daily_Volatility_Pct', 'Annual_Return_Pct', 'Annual_Volatility_Pct', 'volatility']
    df_volatility_output = df_volatility_output[volatility_cols]

    # Create a summary DataFrame for the final Sharpe ratios
    summary_data = {
        'distribution_type': ['Sharpe Ratio Based', 'Inverse Volatility Based'],
        'final_sharpe_ratio': [sharpe_portfolio_sharpe, volatility_portfolio_sharpe]
    }
    summary_df = pd.DataFrame(summary_data)

    # Save the combined results to a single CSV file
    with open('combined_portfolio_distribution.csv', 'w') as f:
        f.write("--- Sharpe Ratio Based Portfolio Distribution ---\n")
        df_sharpe_output.to_csv(f, index=False, float_format='%.4f')
        f.write("\n")
        f.write("--- Inverse Volatility Based Portfolio Distribution ---\n")
        df_volatility_output.to_csv(f, index=False, float_format='%.4f')
        f.write("\n")
        f.write("--- Final Portfolio Sharpe Ratios ---\n")
        summary_df.to_csv(f, index=False)

    # Clean up individual files if they exist
    if os.path.exists('sharpe_ratio_portfolio_distribution.csv'):
        os.remove('sharpe_ratio_portfolio_distribution.csv')
    if os.path.exists('volatility_portfolio_distribution.csv'):
        os.remove('volatility_portfolio_distribution.csv')

if __name__ == '__main__':
    main() 