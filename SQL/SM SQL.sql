create database stock_market;
use stock_market;

#2. Average Daily Trading Volume = Avg(Trading Volume)
SELECT 
    AVG(volume) AS avg_daily_trading_volume
FROM fact_daily_prices;

#3. Volatility (Std Dev of Daily Returns)
WITH returns AS (
    SELECT 
        company_id,
        date,
        (close - LAG(close) OVER (PARTITION BY company_id ORDER BY date)) / LAG(close) OVER (PARTITION BY company_id ORDER BY date) AS daily_return
    FROM fact_daily_prices
)
SELECT 
    company_id,
    STDDEV(daily_return) AS volatility
FROM returns
GROUP BY company_id;

#4. Top Performing Sector
WITH returns AS (
    SELECT 
        dp.company_id,
        (dp.close - LAG(dp.close) OVER (PARTITION BY dp.company_id ORDER BY dp.date)) / LAG(dp.close) OVER (PARTITION BY dp.company_id ORDER BY dp.date) AS daily_return
    FROM fact_daily_prices dp
)
SELECT 
    s.sector_name,
    AVG(r.daily_return) AS avg_return
FROM returns r
JOIN dim_company c ON r.company_id = c.company_id
JOIN dim_sector s ON c.sector_id = s.sector_id
GROUP BY s.sector_name
ORDER BY avg_return DESC
LIMIT 1;

#5. Portfolio Value
SELECT 
    ps.portfolio_id,
    SUM(ps.quantity * dp.close) AS portfolio_value
FROM fact_positions_snapshot ps
JOIN fact_daily_prices dp 
  ON ps.company_id = dp.company_id 
 AND dp.date = (SELECT MAX(date) FROM fact_daily_prices)
GROUP BY ps.portfolio_id;


# 7. Dividend Yield
SELECT 
    c.company_name,
    (d.dividend_per_share / dp.close) * 100 AS dividend_yield_pct
FROM fact_dividends d
JOIN fact_daily_prices dp 
  ON d.company_id = dp.company_id 
 AND d.date = dp.date
JOIN dim_company c ON d.company_id = c.company_id
WHERE dp.date = (SELECT MAX(date) FROM fact_daily_prices);

#9. Order Execution Rate
SELECT 
    ROUND(
        (SUM(CASE 
                WHEN LOWER(status) IN ('executed', 'filled', 'completed') THEN 1 
                ELSE 0 
             END) * 100.0 / COUNT(*)),
        2
    ) AS order_execution_rate_pct
FROM fact_orders;

#10. Trade Win Rate
SELECT 
    (SUM(CASE WHEN (side = 'Sell' AND price > (SELECT AVG(price) FROM fact_trades WHERE side = 'Buy' AND company_id = t.company_id)) THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS trade_win_rate_pct
FROM fact_trades t;

#11. Trader Performance
SELECT 
    trader_id,
    SUM(CASE WHEN side = 'Sell' THEN quantity * price ELSE -quantity * price END) AS pnl
FROM fact_trades
GROUP BY trader_id
ORDER BY pnl DESC;

SELECT 
    SUM(dp.close * c.outstanding_shares) AS total_market_cap
FROM fact_daily_prices dp
JOIN dim_company c ON dp.company_id = c.company_id
WHERE dp.date = (SELECT MAX(date) FROM fact_daily_prices);
