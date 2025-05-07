WITH checking AS (
	SELECT SUM(sales) AS conditioning 
    FROM orders
    WHERE state_province = "Alabama"),
total AS (
	SELECT SUM(sales) as total
	FROM orders), 
result AS (
	SELECT conditioning
    FROM checking 
    UNION 
    SELECT total 
    FROM total)
-- Cross Checking with Total Sales and 
SELECT (conditioning/1924337.88) * 100 As results
FROM checking
UNION 
SELECT (conditioning/357105.12) * 100 AS results
FROM checking;

-- Sales Analysis 
CREATE TEMPORARY TABLE indexing AS 
SELECT sales FROM orders 
ORDER BY sales;
-- Ranking Based Search
SELECT * 
FROM(
	SELECT *, 
		ROW_NUMBER() OVER() AS numbering 
	FROM indexing) AS happy 
WHERE numbering = 863;
-- Value Based Search
SELECT *, 
	ROW_NUMBER() OVER() AS numbering 
FROM indexing
WHERE Sales <= 3000;

-- Month On Month Sales Difference
SELECT *, 
	(total_sales - LAG(total_sales) OVER(order by monthly) )
FROM(
SELECT 
	MONTH(order_date) AS monthly, 
    SUM(sales) AS total_sales
FROM orders
GROUP BY monthly
ORDER BY 1) AS happy;

-- Avg Sales Percentage Change on monthly basis
SELECT avg(percentage_change) AS average 
FROM (
	SELECT *,
		   ROUND(((total_sales - LAG(total_sales) OVER (ORDER BY monthly)) / 
				 LAG(total_sales) OVER (ORDER BY monthly)) * 100, 2) AS percentage_change
	FROM (
		SELECT MONTH(order_date) AS monthly,
			   SUM(sales) AS total_sales
		FROM orders
		GROUP BY monthly
	) AS happy
) AS subquery;

-- Compairing Avg Sales and Avg of Sales when Grouped by month 
SELECT AVG(sales) AS sales 
FROM orders
UNION ALL
SELECT AVG(sales) FROM (SELECT MONTH(order_date) AS monthly, SUM(Sales) AS sales
FROM orders
GROUP BY 1) AS happy;

-- Month Wise Region and Sales Analysis
SELECT MONTH(order_date) AS monthly, region, SUM(sales) AS sales
FROM orders
GROUP BY 1, 2
ORDER BY 1;

/*
WITH churn_rate_monthly AS (
	SELECT 
		customer_id, 
		MONTH(order_date) AS months
	FROM orders
    GROUP BY customer_id, 2
	ORDER BY 2 DESC ),
conditioning AS (
		SELECT
			*, 
			CASE WHEN 
			AS retained
		FROM churn_rate_monthly AS cr1
        LEFT JOIN churn_rate_monthly AS cr2
        ON cr1.customer_id = cr2.customer_id
        AND 
        WHERE cr2.customer_id 
)
;*/

-- Creating Custom Table For Churn Rate and Retention Rate Calculation in Power BI
CREATE TEMPORARY TABLE results AS
-- Step 1: Extract customer and month
WITH monthly_customers AS (
    SELECT 
        customer_id,
        LAST_DAY(order_date) + INTERVAL 1 DAY - INTERVAL DAY(LAST_DAY(order_date)) DAY AS month_start
    FROM orders
    GROUP BY customer_id, LAST_DAY(order_date) + INTERVAL 1 DAY - INTERVAL DAY(LAST_DAY(order_date)) DAY
),

-- Step 2: Join current and previous month
customer_churn_flag AS (
    SELECT 
        curr.customer_id,
        CAST(curr.month_start AS DATE) AS current_month,
        CAST(prev.month_start AS DATE) AS previous_month,
        IF(prev.customer_id IS NULL, 'No', 'Yes') AS retained
    FROM monthly_customers curr
    LEFT JOIN monthly_customers prev
        ON curr.customer_id = prev.customer_id
        AND prev.month_start = curr.month_start - INTERVAL 1 MONTH
)
#/*
-- Step 3: Result
SELECT *
FROM customer_churn_flag
ORDER BY current_month, customer_id;
#*/
-- Cross Checking
#SELECT * FROM results;

-- Now Joining State_Province & Region For Better Demographical Analysis 
WITH distincting AS (
SELECT 
	customer_id,
	state_province,
    region
FROM orders
GROUP BY 1,2,3 ),

CTE AS(
SELECT 
	r.customer_id,
    r.current_month,
    r.previous_month,
    r.retained,
	o.state_province, 
    o.region 
FROM results AS r
LEFT JOIN distincting AS o
ON r.customer_id = o.customer_id)

SELECT * FROM CTE;

DESCRIBE orders;

-- Rough
SELECT 
	ship_mode,
    COUNT(order_id) AS counts
FROM orders
GROUP BY 1;

SELECT * FROM orders;

-- Rough
SELECT 
	COUNT(order_id),
    COUNT(DISTINCT order_id)
FROM
(
SELECT 
	order_id,
	order_date, 
    ship_date,
	datediff(ship_date, order_date)
FROM orders 
) AS happy;

-- Most used Shipping Mode in each State
SELECT * FROM (
SELECT *, 
	ROW_NUMBER() OVER(PARTITION BY state_province ORDER BY total_profits DESC, counts DESC) AS ranking
FROM 
(SELECT 
	state_province, 
	ship_mode, 
	COUNT(ship_mode) AS counts,
    SUM(profit) AS total_profits
FROM orders
GROUP BY 1 , 2
ORDER BY 3 DESC, 1) AS rankings) AS final
WHERE ranking = 1;

-- Category wise % Contribution
WITH CTE AS  (
SELECT 
	product_category,
    product_sub_category,
    count(*) AS total_orders
FROM orders
GROUP BY 1, 2),
total AS(
SELECT 
	product_category, 
    COUNT(*) AS grand_total 
FROM orders
GROUP BY 1),
percentage AS(
SELECT 
	c.product_category,
    product_sub_category,
    grand_total,
    total_orders,
    (total_orders / grand_total) * 100 AS percentage
FROM CTE as c
LEFT JOIN total as t
ON c.product_category = t.product_category) 
SELECT * FROM percentage
;

-- Median Profit
WITH numbering as (
SELECT 
	profit,
	row_number() OVER() AS ranking
FROM orders
ORDER BY sales
),
selecting as (
SELECT 
	*
FROM numbering
WHERE ranking = 937
)
SELECT * FROM selecting;

-- Selecting the Top State which contributes to the most amount of profit per month
SELECT * FROM 
(
SELECT *, ROW_NUMBER() OVER(partition by months ORDER BY profits DESC) AS ranking
FROM (
SELECT 
	MONTH(order_date) AS months,
	state_province, 
    SUM(profit) AS profits
FROM orders
GROUP BY 1, 2
ORDER BY 1 )  AS happy ) AS result
WHERE ranking <= 1;

-- Sales And Profit Percentage contribution 
SELECT 
	month(order_date),
    SUM(profit) AS profits,
    (SUM(profit) / 213541.50) * 100 AS percentage,
    SUM(sales) AS sales,
    (SUM(sales) / 1886890.76) *100 AS percentage 
FROM orders
GROUP BY 1
ORDER BY 1;

SELECT SUM(sales)
FROM orders;

-- % Growth in Sales per Month
SELECT *,
	((sales - LAG(sales) OVER()) / LAG(sales) OVER()) * 100 AS percentage
FROM (
SELECT 
	MONTH(order_date) As months,
    SUM(sales) AS sales
FROM orders
GROUP BY 1 
ORDER BY 1) AS happy;