use superstore_us_new;

SELECT * FROM orders;

-- finding out the details of the customers who returned their order
SELECT * 
FROM orders
WHERE order_id IN( 
	SELECT 
	DISTINCT order_id
	FROM ORDERS
	INNER JOIN o_return
	USING(order_id)
);
#Cross Checking 
SELECT * FROM orders WHERE row_id = 5059;
SELECT * FROM o_return WHERE order_id = 5059;

SELECT
	product_sub_category, 
	LENGTH(product_sub_category) AS char_len
FROM orders 
WHERE LENGTH(product_sub_category) > 15
GROUP BY product_sub_category
ORDER BY char_len DESC;

-- Lets declare some changes
#Replacing and with &
UPDATE orders
SET product_sub_category = REPLACE(product_sub_category, 'and', ' & ') 
WHERE product_sub_category LIKE '%and%';
#Replacing "Binders and Binder Accessories" with "Binders and Accessories"
UPDATE orders
SET product_sub_category = REPLACE(product_sub_category, 'Binders and Binder Accessories', 'Binders and Accessories') 
WHERE product_sub_category = 'Binders and Binder Accessories';


-- Rexgex Expression
SELECT 
	product_name 
FROM orders
WHERE product_name REGEXP '[0-9]{3,}$';

-- Finding out the products who's ODV is lower than of the average order value
# USING TEMPORARY TABLES FOR THIS 
CREATE TEMPORARY TABLE sample 
SELECT product_name, ROUND(AVG(sales), 2) AS sales FROM orders GROUP BY 1;
#CROSS CHECKING
SELECT * FROM sample WHERE product_name LIKE 'Motorola%';
# ANSWER
SELECT 
sample.*, 
orders.sales
FROM orders
JOIN sample
ON orders.product_name = sample.product_name
WHERE orders.sales < sample.sales;

-- Most and Least sales done in a Month/ STATE/ REGION/ PRODUCTS/ SUB-PRODUCT WISE.
 # MONTH WISE DIVISION
 SELECT 
	MONTH(order_date) AS MONTHLY, 
    SUM(sales) AS TOTAL 
FROM ORDERS 
GROUP BY MONTHLY 
ORDER BY MONTHLY, TOTAL DESC;
# STATE WISE
SELECT 
	MONTH(order_date) AS months, 
    state_province, 
    SUM(sales) AS t_sales
FROM orders
GROUP BY months, state_province
ORDER BY months, t_sales DESC;
# SUB_PRODUCTS WITH ROLLUP
SELECT 
	MONTH(order_date) AS months, 
    product_sub_category, 
    SUM(sales) AS t_sales
FROM orders
GROUP BY months, product_sub_category
WITH ROLLUP
ORDER BY months, t_sales DESC;

-- CUMULATIVE PERCENTAGE OF EACH product_sub_category OF TOTAL SALES
# A different approach
SELECT *, 
	SUM(rev_pct) OVER (ORDER BY rev_pct) AS cumulative_sum_perc FROM (
		SELECT *, 
			ROUND(((revenue / total_sales) * 100), 2) AS rev_pct 
		FROM(
			SELECT 
				product_sub_category, 
                SUM(sales) AS revenue, 
					(SELECT ROUND(SUM(sales), 0) FROM orders) as total_sales
			FROM orders
		GROUP BY 1) as happy
) as happy2;

-- SELECTING THE MOST ORDERD product_sub_category FOR EVERY REGION.
SELECT 
	region, 
    product_sub_category, 
    MAX(occurance) AS max_occurance
FROM (
    SELECT 
		product_sub_category, 
        region, 
        COUNT(product_sub_category) AS occurance 
    FROM orders
    GROUP BY product_sub_category, region
) AS happy
GROUP BY region, product_sub_category
HAVING max_occurance = (
    SELECT MAX(occurance)
    FROM (
        SELECT COUNT(product_sub_category) AS occurance
        FROM orders
        WHERE region = happy.region
        GROUP BY product_sub_category
    ) AS region_occurances
);
-- ALTERNATIVE AND EASY APPROACH
SELECT * FROM (
	SELECT *, 
		DENSE_RANK() OVER(PARTITION BY region ORDER BY occurance DESC) as top_most
	FROM (
		SELECT 
			product_sub_category, 
			region,
			COUNT(*) AS occurance 
		FROM orders
		GROUP BY product_sub_category, region) AS happy
	) as happy2 
HAVING top_most = 1;

-- Finding Customers's First Order Date
WITH first_order AS (SELECT 
	MIN(order_date) as first_order,
	customer_id, 
	customer_name
FROM orders
GROUP BY customer_id, customer_name
ORDER BY first_order),
#LAST ORDER WITH DATE DIFFERENCE
last_order AS (SELECT 
	MIN(order_date) as first_order,
	customer_id, 
	customer_name,
    MAX(order_date) AS last_order,
    DATEDIFF(MAX(order_date), MIN(order_date)) AS inactive_days
FROM orders
GROUP BY customer_id, customer_name
ORDER BY first_order),
#ANALYZING USING BINS OF 10 DAYS
with_bins AS (SELECT 
	ROUND(inactive_days, -1) AS day_bracket,
    COUNT(customer_id) AS no_of_customers
FROM last_order
GROUP BY day_bracket
ORDER BY day_bracket)

SELECT * FROM last_order
ORDER BY inactive_days DESC;
#SELECT * FROM with_bins;
#crosschecking
SELECT * FROM ORDERS WHERE customer_name = 'Gary Koch';

# Providing customers with coupon if the last order date is more than 118 days
SELECT *,
CASE 
	WHEN last_order >= 118 THEN 'Coupon Eligible'
END AS promotional  
FROM (SELECT * , 
		DATEDIFF(today, last_date) AS last_order 
	FROM (Select customer_id, 
			customer_name,
			MAX(order_date) AS last_date, 
			'2015-06-28' as today 
		FROM orders
		GROUP BY 1,2) as happy
	) as conditional;

-- Finding orders which have the order_value more than the avg(monthly_region_category_sale) value
WITH CTE AS (
	SELECT month(order_date) as monthly,
		region, 
        product_sub_category, 
        ROUND(AVG(sales), 0) AS avg_sales
	FROM orders
	GROUP BY monthly, region, product_sub_category),
CTE2 AS (
	SELECT customer_id,
		MONTH(order_date) AS month_wise, 
        region, 
        product_sub_category, 
        product_name, 
        sales, 
        profit 
    FROM orders)

SELECT CTE2.customer_id, 
	CTE2.month_wise, 
    CTE2.region, 
    CTE2.product_sub_category, 
    CTE2.product_name, 
    CTE2.sales, 
    CTE2.profit, 
    avg_sales 
FROM CTE2 
LEFT JOIN CTE 
ON CTE2.month_wise = CTE.monthly 
	AND CTE2.product_sub_category = CTE.product_sub_category
	AND CTE2.region = CTE.region
WHERE sales > avg_sales
ORDER BY month_wise, region;

-- Customer Retention Rate Per Month 
WITH CTE AS (
	SELECT 
		DATE_FORMAT(order_date, '%Y-%m-01') AS monthly,
        customer_id
	FROM orders),
retention_count AS(
	SELECT 
		previous.monthly AS monthly,
		COUNT(DISTINCT current.customer_id) AS retention_count
	FROM CTE AS previous
	LEFT JOIN CTE AS current
	ON previous.customer_id = current.customer_id
	AND CAST(current.monthly AS DATE) = (DATE_SUB(CAST(previous.monthly AS DATE), INTERVAL 1 MONTH))
	GROUP BY 1
	ORDER BY 1)
SELECT 
	rc.monthly,
    retention_count,
    COUNT(DISTINCT customer_id) AS total_count, 
	ROUND(retention_count/COUNT(DISTINCT customer_id), 2) AS retention_rate
FROM retention_count AS rc
LEFT JOIN CTE AS c
ON rc.monthly = c.monthly
GROUP BY 1, 2;
# Cross Checking
WITH first_m AS(
	SELECT 
		MONTH(order_date),
		customer_id
	FROM orders
    WHERE MONTH(order_date) = 1),
second_m AS (
	SELECT 
		MONTH(order_date),
		customer_id
	FROM orders
    WHERE MONTH(order_date) = 2)

SELECT 
	'Total Retained Customers' AS Category,	
	COUNT(DISTINCT customer_id) AS Counts 
FROM (
	SELECT * 
    FROM first_m
	WHERE customer_id IN (
		SELECT 
			customer_id 
		FROM second_m)
	) AS happy 
UNION 
SELECT 
	'Total Distinct Customers' AS Categoy,
	COUNT(DISTINCT customer_id) AS Counts
FROM second_m;

-- Customer Churn Rate per Month
WITH CTE AS (SELECT 
	DATE_FORMAT(order_date, '%Y-%m-01') AS months,
	customer_id
FROM orders),
churn_count AS (
SELECT 
	previous.months AS months,
	COUNT(DISTINCT previous.customer_id) AS customer_churn
FROM CTE AS previous
LEFT JOIN CTE AS ongoing
	ON ongoing.customer_id = previous.customer_id
	AND CAST(ongoing.months AS DATE) = (DATE_SUB(CAST(previous.months AS DATE),  INTERVAL 1 MONTH))
WHERE ongoing.customer_id IS NULL
GROUP BY 1 
ORDER BY 1)

SELECT 
	cc.months, 
    customer_churn,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(customer_churn/COUNT(DISTINCT customer_id), 2) AS churn_rate
FROM churn_count as cc
LEFT JOIN CTE
ON cc.months = CTE.months
GROUP BY months, customer_churn;


SELECT 
* 
FROM orders o 
left JOIN o_return ors
ON o.order_id = ors.order_id;




SELECT* FROM o_return;