import pandas as pd
import numpy as np
import os

def clean_pair_name(file_name):
    """Extracts the pair name from the file name."""
    if isinstance(file_name, str):
        # Example: EURUSD_GBPUSD_divergence_backtest_report.csv -> EURUSD_GBPUSD
        parts = file_name.split('_')
        if len(parts) >= 2:
            return f"{parts[0]}_{parts[1]}"
    return file_name

def calculate_portfolio_distribution():
    """
    Loads data from positive and negative correlation reports, calculates portfolio
    distribution based on volatility and Sharpe ratio, and saves the combined report.
    """
    # Define file paths
    neg_corr_file = 'Neg Corelation/high_sharpe_ratio_pairs.csv'
    pos_corr_file = 'Pos Corelation/high_sharpe_ratio_pairs.csv'
    output_file = 'combined_portfolio_distribution.csv'

    # Load the datasets
    try:
        neg_df = pd.read_csv(neg_corr_file)
        pos_df = pd.read_csv(pos_corr_file)
    except FileNotFoundError as e:
        print(f"Error loading file: {e}. Please ensure the files exist.")
        return

    # --- Data Standardization ---

    # 1. Add correlation type
    neg_df['correlation_type'] = 'Negative'
    pos_df['correlation_type'] = 'Positive'

    # 2. Standardize column names for the positive correlation dataframe
    pos_df.rename(columns={
        'Pair': 'pair',
        'Sharpe Ratio': 'sharpe_ratio',
        'Volatility': 'volatility',
        'Average Trade Duration (Hours)': 'avg_trade_duration',
        'Total Trades': 'total_trades',
        'Total Profit': 'total_profit',
        'Buy Trades': 'total_buy_trades',
        'Sell Trades': 'total_sell_trades',
        'Max Loss': 'max_loss',
        'Average Win': 'avg_win',
        'Average Loss': 'avg_loss'
    }, inplace=True)

    # 3. Clean the 'pair' column in the positive dataframe
    pos_df['pair'] = pos_df['pair'].apply(clean_pair_name)
    
    # We only need a subset of columns for the final report
    # to make them consistent before merging.
    common_columns = [
        'pair', 'sharpe_ratio', 'volatility', 'total_trades',
        'total_profit', 'max_loss', 'correlation_type'
    ]
    
    # Filter both dataframes to only include common columns
    neg_df_common = neg_df[[col for col in common_columns if col in neg_df.columns]]
    pos_df_common = pos_df[[col for col in common_columns if col in pos_df.columns]]

    # Combine the two dataframes
    combined_df = pd.concat([neg_df_common, pos_df_common], ignore_index=True)

    # --- Portfolio Weight Calculation ---

    # Ensure dtypes are correct for calculation
    combined_df['volatility'] = pd.to_numeric(combined_df['volatility'], errors='coerce')
    combined_df['sharpe_ratio'] = pd.to_numeric(combined_df['sharpe_ratio'], errors='coerce')
    combined_df.dropna(subset=['volatility', 'sharpe_ratio'], inplace=True)


    # 1. Volatility Based Portfolio (Inverse Volatility Weighting)
    # We add a small epsilon to handle cases where volatility might be zero.
    epsilon = 1e-9
    inverse_volatility = 1 / (combined_df['volatility'] + epsilon)
    total_inverse_volatility = inverse_volatility.sum()
    volatility_based_weight = inverse_volatility / total_inverse_volatility

    # 2. Sharpe Ratio Based Portfolio
    # Weights are proportional to the Sharpe ratio. Negative Sharpe ratios are treated as 0 weight.
    sharpe_for_weighting = combined_df['sharpe_ratio'].clip(lower=0)
    total_sharpe = sharpe_for_weighting.sum()
    
    if total_sharpe > 0:
        sharpe_based_weight = sharpe_for_weighting / total_sharpe
    else:
        # Avoid division by zero if all sharpe ratios are non-positive
        sharpe_based_weight = 0.0

    # --- Investment Return Calculation ---
    INVESTMENT_AMOUNT = 100000

    combined_df['capital_allocated_vol_based'] = volatility_based_weight * INVESTMENT_AMOUNT
    combined_df['capital_allocated_sharpe_based'] = sharpe_based_weight * INVESTMENT_AMOUNT

    # Calculate expected total profit based on historical data and portfolio weights
    expected_profit_vol_based = (volatility_based_weight * combined_df['total_profit']).sum()
    expected_profit_sharpe_based = (sharpe_based_weight * combined_df['total_profit']).sum()

    # --- Final Calculations and Formatting ---

    # 1. Calculate final portfolio Sharpe Ratios
    portfolio_sharpe_vol_weighted = (combined_df['sharpe_ratio'] * volatility_based_weight).sum()
    portfolio_sharpe_sharpe_weighted = (combined_df['sharpe_ratio'] * sharpe_based_weight).sum()

    combined_df['volatility_based_weight'] = volatility_based_weight
    combined_df['sharpe_based_weight'] = sharpe_based_weight
    combined_df['portfolio_sharpe_vol_weighted'] = portfolio_sharpe_vol_weighted
    combined_df['portfolio_sharpe_sharpe_weighted'] = portfolio_sharpe_sharpe_weighted

    # 2. Format weights as percentages
    combined_df['volatility_based_weight'] = combined_df['volatility_based_weight'].apply(lambda x: f"{x:.2%}")
    combined_df['sharpe_based_weight'] = combined_df['sharpe_based_weight'].apply(lambda x: f"{x:.2%}")

    # Save the final combined report
    combined_df.to_csv(output_file, index=False)
    print(f"Successfully created '{output_file}'")

    # Print the projected returns summary
    print(f"\n--- Projected Returns for a ${INVESTMENT_AMOUNT:,} Investment ---")
    print(f"Based on Volatility-Weighted Portfolio: ${expected_profit_vol_based:,.2f}")
    print(f"Based on Sharpe Ratio-Weighted Portfolio: ${expected_profit_sharpe_based:,.2f}")
    print("\nNote: These projections are based on historical total profits from the backtest period and do not guarantee future returns.")

if __name__ == "__main__":
    calculate_portfolio_distribution() 