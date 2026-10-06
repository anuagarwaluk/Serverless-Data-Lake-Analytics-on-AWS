-- Serverless Data Lake Analytics: Athena queries
-- Tables: sales (partitioned by year/month/day), customers, products
-- Catalogued by AWS Glue Crawler; queried in place on S3.

-- 1. Sample the data
SELECT * FROM sales LIMIT 10;

-- 2. Total orders
SELECT COUNT(*) AS total_orders FROM sales;

-- 3. Total revenue
SELECT ROUND(SUM(quantity * price), 2) AS total_revenue
FROM sales;

-- 4. Revenue by region
SELECT region,
       COUNT(*) AS order_count,
       ROUND(SUM(quantity * price), 2) AS revenue
FROM sales
GROUP BY region
ORDER BY revenue DESC;

-- 5. Top customers by spend (join sales -> customers)
SELECT c.name,
       c.tier,
       COUNT(s.order_id) AS total_orders,
       ROUND(SUM(s.quantity * s.price), 2) AS total_spent
FROM sales s
JOIN customers c ON s.customer_id = c.customer_id
GROUP BY c.name, c.tier
ORDER BY total_spent DESC
LIMIT 10;

-- 6. Product profitability (join sales -> products)
SELECT p.name,
       p.category,
       COUNT(s.order_id) AS times_ordered,
       SUM(s.quantity) AS units_sold,
       ROUND(SUM(s.quantity * s.price), 2) AS revenue,
       ROUND(SUM(s.quantity * (s.price - p.cost_price)), 2) AS profit
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.name, p.category
ORDER BY profit DESC;

-- 7. Customer tier analysis
SELECT c.tier,
       COUNT(DISTINCT c.customer_id) AS customer_count,
       COUNT(s.order_id) AS total_orders,
       ROUND(AVG(s.quantity * s.price), 2) AS avg_order_value
FROM customers c
LEFT JOIN sales s ON c.customer_id = s.customer_id
GROUP BY c.tier
ORDER BY avg_order_value DESC;

-- 8. Partition pruning comparison
-- Full scan: no partition filter, reads every file under raw-data/sales/
SELECT *
FROM sales
WHERE order_timestamp = '2025-01-15 00:00:00';

-- Pruned scan: partition filter, reads only year=2025/month=01/day=15/
SELECT COUNT(*)
FROM sales
WHERE year = '2025' AND month = '01' AND day = '15';

-- 9. Convert CSV to Parquet with CTAS, then compare data scanned
CREATE TABLE sales_parquet
WITH (format = 'PARQUET') AS
SELECT * FROM sales;

SELECT * FROM sales;          -- scans the full CSV
SELECT * FROM sales_parquet;  -- scans a fraction: columnar + compressed
