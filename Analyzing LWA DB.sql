/*
THE GOAL: analyze the database records of Level Won Apparel and develop a view of how strong the business is 



1. CASH FLOW FINANCIALS - ANNUAL & QUARTERLY
    KEY QUESTIONS:
		1. What are the annual trends for money coming into the business, as measured by unique customers, quantity of items sold,
        revenue, cost of goods sold, margin, and average order value?
        2. How many refunds were given by year, and what amount of money left the business via refunds?
        3. Create an annual financials table that shows all of the summary stats named above, and also includes the
        following: refund rate, total losses from refunds, and margin after refund losses were subtracted from revenue.
        4. Create that same table (as #3) but with a quarterly view.
        5. Appendix: why I used temporary tables instead of joining 'orders' and 'order_item_refunds'. 
*/

-- 1. Annual trends: money entering the business.

SELECT
    YEAR(created_at) AS year,
    COUNT(DISTINCT user_id) AS unique_customers,
    SUM(items_purchased) AS qty_sold,
    SUM(price_usd) AS revenue,
    SUM(cogs_usd) AS total_cogs,
    SUM(price_usd - cogs_usd) AS margin,
    AVG(price_usd) as AOV
FROM orders
GROUP BY 1;

-- 2. Annual trends: money leaving the business. 

SELECT
	YEAR(created_at) AS year,
    COUNT(DISTINCT order_item_refund_id) AS qty_refunds,
    SUM(refund_amount_usd) as refund_volume_usd
FROM order_item_refunds
GROUP BY 1; 

-- 3. Annual trends: combined table with additional summary stats. 

CREATE TEMPORARY TABLE annual_financials
SELECT
    YEAR(created_at) AS year,
    COUNT(DISTINCT user_id) AS unique_customers,
    SUM(items_purchased) AS qty_sold,
    SUM(price_usd) AS revenue,
    SUM(cogs_usd) AS total_cogs,
    SUM(price_usd - cogs_usd) AS margin,
    AVG(price_usd) as AOV
FROM orders
GROUP BY 1;

-- QA only: SELECT * FROM annual_financials;

/* have to stamp a second temporary table in order 
to join the two tables on 'year' values */

CREATE TEMPORARY TABLE refund_volume_by_year
SELECT
	YEAR(created_at) AS year,
    COUNT(DISTINCT order_item_refund_id) AS qty_refunds,
    SUM(refund_amount_usd) as refund_volume_usd
FROM order_item_refunds
GROUP BY 1;

-- QA only: SELECT * FROM refund_volume_by_year;

SELECT
	annual_financials.year AS year,
    unique_customers,
    qty_sold,
    qty_refunds,
    revenue AS revenue_usd,
    refund_volume_usd,
    total_cogs,
    margin,
    AOV
FROM annual_financials
	LEFT JOIN refund_volume_by_year
		ON annual_financials.year = refund_volume_by_year.year
;

-- finally, I'll add a few more columns to get more summary stats:
						
                        -- FINAL TABLE: FINANCIAL SUMMARY STATS - ANNUAL VIEW
SELECT
	annual_financials.year AS year,
    unique_customers,
    qty_sold,
    qty_refunds,
    qty_refunds/qty_sold AS refund_rate,-- added refund_rate
    revenue AS revenue_usd,
    refund_volume_usd,
    total_cogs,
    refund_volume_usd + total_cogs AS total_refund_losses, -- added total_refund_losses
    margin,
    (revenue - (refund_volume_usd + total_cogs)) AS margin_less_refund_losses,-- added margin_less_refund_losses
    AOV
FROM annual_financials
	LEFT JOIN refund_volume_by_year
		ON annual_financials.year = refund_volume_by_year.year;


-- 4. Quarterly trends: summary stats from the annual table, but shown by quarter. 

CREATE TEMPORARY TABLE quarterly_financials
SELECT
	CONCAT(YEAR(created_at),'-',QUARTER(created_at)) AS orders_yq_id, -- adding to ensure correct join
    YEAR(created_at) AS order_year,
    QUARTER(created_at) AS order_quarter, -- added this
    COUNT(DISTINCT user_id) AS unique_customers,
    SUM(items_purchased) AS qty_sold,
    SUM(price_usd) AS revenue,
    SUM(cogs_usd) AS total_cogs,
    SUM(price_usd - cogs_usd) AS margin,
    AVG(price_usd) as AOV
FROM orders
GROUP BY 1,2,3 -- added '2' and '3' here
ORDER BY 1,2 ASC -- added this line
;
-- QA only: SELECT * FROM quarterly_financials;

CREATE TEMPORARY TABLE refund_volume_by_quarter
SELECT
	CONCAT(YEAR(created_at),'-',QUARTER(created_at)) AS refunds_yq_id, -- added to ensure correct join
	YEAR(created_at) AS refund_year,
    QUARTER(created_at) AS refund_quarter, -- added this line
    COUNT(DISTINCT order_item_refund_id) AS qty_refunds,
    SUM(refund_amount_usd) as refund_volume_usd
FROM order_item_refunds
GROUP BY 1,2,3 -- added '2' and '3' here
ORDER BY 1,2 ASC -- added this line
;
-- QA only: SELECT * FROM refund_volume_by_quarter;

-- this join below only works because of the yq_id's that we concatenated above
	-- also added the 3 additional summary stats from the annual view 
    
                        -- FINAL TABLE: FINANCIAL SUMMARY STATS - QUARTERLY VIEW
SELECT
	order_year AS year,
    order_quarter AS quarter,
    unique_customers,
    qty_sold,
    qty_refunds,
    qty_refunds/qty_sold AS refund_rate,
    revenue AS revenue_usd,
    refund_volume_usd,
    total_cogs AS cogs_usd,
    refund_volume_usd + total_cogs AS total_refund_losses,
    margin,
    (revenue - (refund_volume_usd + total_cogs)) AS margin_less_refund_losses,
    AOV
FROM quarterly_financials
	LEFT JOIN refund_volume_by_quarter
		ON quarterly_financials.orders_yq_id = refund_volume_by_quarter.refunds_yq_id
ORDER BY 1,2 ASC;


-- 5. Appendix: investigation of problems arising from 'orders' and 'order_item_refunds' JOIN approach.

/*
Next, I'll join them together to create one view.

	Note: I'm using temporary tables after this long comment section because using 
    a LEFT JOIN to bring 'order_item_refunds' to 'orders' would cause a problem. 
    Per the query below, under 'INVESTIGATION AUDIT #1', there are 8 order_id values 
    that repeat in the 'order_item_refunds' table, which is fine because order_id is 
    a foreign key. The repeating order_id values mean that some orders had multiple 
    items refunded, which would make sense assuming that the orders had multiple items. 

-- INVESTIGATION AUDIT #1
	-- PURPOSE: check whether there are duplicate order_id values in 'order_item_refunds', to prevent the
				creation of extra records via a LEFT JOIN

	-- compare the results of the query below with those from the query starting on line 44
		-- you'll see that the SUM aggregations are off 
	SELECT
		YEAR(orders.created_at) AS year,
		SUM(orders.items_purchased) AS qty_sold,
		SUM(orders.price_usd) AS revenue,
		SUM(orders.cogs_usd) AS total_cogs,
		SUM(orders.price_usd - orders.cogs_usd) AS margin
	FROM orders
		LEFT JOIN order_item_refunds
			ON orders.order_id = order_item_refunds.order_id
	GROUP BY 1
	;

	-- the results of the query below show why we get extra rows by highlighting the duplicate order_id's
	SELECT
		COUNT(orders.order_id),
		COUNT(DISTINCT orders.order_id),
		COUNT(orders.order_id) - COUNT(DISTINCT orders.order_id) AS dupes_in_orders,
		COUNT(order_item_refunds.order_id),
		COUNT(DISTINCT order_item_refunds.order_id),
		COUNT(order_item_refunds.order_id) - COUNT(DISTINCT order_item_refunds.order_id) AS dupes_in_order_item_refunds
	FROM orders
		LEFT JOIN order_item_refunds
			ON orders.order_id = order_item_refunds.order_id
	;


-- INVESTIGATION AUDIT #2
	-- PURPOSE: identify the 8 order_id values that repeat in 'order_item_refunds', to verify whether
				those orders contained multiple items

	-- CREATE TEMPORARY TABLE first_item_return_date_per_order
	SELECT
		MIN(created_at) as first_item_returned_at,
		order_id
	FROM order_item_refunds
	GROUP BY 2
	;

	-- this statement below separates out the 8 order_item_refund_id's whose order_id's were duplicated
	SELECT *
	FROM order_item_refunds
		LEFT JOIN first_item_return_date_per_order
			ON order_item_refunds.created_at = first_item_return_date_per_order.first_item_returned_at
	WHERE first_item_returned_at IS NULL
	ORDER BY created_at DESC
	;

	-- the order_id's are '31486','28802', '27061', '24472', '23321', '19848', '19518', '9324'
		-- the next step is to filter the 'orders' table to see whether these order_id's map to orders with more than one product
		
	SELECT *
	FROM orders
	WHERE order_id IN ('31486','28802', '27061', '24472', '23321', '19848', '19518', '9324')

	/* and that query shows us that 2 products were purchased in each of these orders, 
	which means that these orders are the only 8 cases where multiple items were refunded
*/

/*
2. CUSTOMER BASE ANALYSIS
    KEY QUESTIONS:
		1. Shown trending by year, what % of website visitors bought?
        2. Also shown trending by year, how efficienct was the website as measured by revenue per visitor, and revenue per session?
        3. On a per-session basis, how many pages did customers view on average and how does that compare to the non-buying visitors? 
        4. What % of customers purchased more than once, and what was the maximum number of lifetime purchases by one customer?
        5. What was the distribution, by year, of repurchases? 
        6. Shown by year, what was the AOV of initial orders, as well as subsequent (2nd, 3rd, 4th, etc.) orders? 
        7. What % of orders resulted in a refund? 
        8. How many customers received a refund on more than one order?
        9. On an order-item basis, what was the average refund rate, and how many customers had an above-average refund rate? 
        10. How much more valuable is a customer that orders multiple times, as measured by total lifetime spend?
        
	KEY CHALLENGE: the dataset does not have a customer / user data table of any kind at this point in time.
*/


-- 1. Shown trending by year, what % of website visitors bought?

SELECT
	YEAR(website_sessions.created_at) AS year,
    COUNT(DISTINCT orders.user_id)/COUNT(DISTINCT website_sessions.user_id) AS pct_of_visitors_bought
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.user_id = orders.user_id
GROUP BY 1;


-- 2. Also shown trending by year, how efficienct was the website as measured by revenue per visitor, and revenue per session?

SELECT
	YEAR(website_sessions.created_at) AS year,
	SUM(orders.price_usd)/COUNT(DISTINCT website_sessions.user_id) AS revenue_per_visitor,
    SUM(orders.price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.user_id = orders.user_id
GROUP BY 1;


-- 3. On a per-session basis, how many pages did customers view on average, and how does that compare to the non-buying visitors? 
	-- my final table will have the following columns: bucket, average pageviews

CREATE TEMPORARY TABLE pvs_by_session
SELECT
	website_session_id,
    COUNT(DISTINCT website_pageview_id) pvs_by_session
FROM website_pageviews
GROUP BY 1;

CREATE TEMPORARY TABLE sessions_pageviews_ptag
SELECT
	website_sessions.website_session_id,
	pvs_by_session.pvs_by_session,
    CASE
		WHEN orders.website_session_id IS NOT NULL THEN 1 ELSE NULL END AS buy_session_tag
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
	LEFT JOIN pvs_by_session
		ON website_sessions.website_session_id = pvs_by_session.website_session_id;

SELECT
	CASE
		WHEN buy_session_tag = 1 THEN 'customer'
	ELSE 'visitor' END AS bucket,
    AVG(pvs_by_session) AS avg_pageviews_per_session
FROM sessions_pageviews_ptag
GROUP BY 1;


-- 4. What % of customers purchased more than once, and what was the maximum number of lifetime purchases by one customer?

SELECT
	COUNT(order_id) AS order_qty,
    COUNT(DISTINCT user_id) AS unique_customer_count
FROM orders;


CREATE TEMPORARY TABLE order_count_by_customer
SELECT
	user_id AS customer_id,
    COUNT(DISTINCT order_id) AS order_count
FROM orders
GROUP BY 1;

SELECT
	order_count AS qty_lifetime_orders,
	COUNT(DISTINCT customer_id) AS users_per_bucket,
    
    CASE
		WHEN order_count = 1 THEN (COUNT(DISTINCT customer_id)/31696)
        WHEN order_count = 2 THEN (COUNT(DISTINCT customer_id)/31696)
        WHEN order_count = 3 THEN (COUNT(DISTINCT customer_id)/31696)
	ELSE NULL END AS pct_of_customers
    
FROM order_count_by_customer
GROUP BY 1;


-- 5. What was the distribution, by year, of repurchases? 

CREATE TEMPORARY TABLE first_order_id_per_customer
SELECT
	user_id AS customer_id,
    MIN(order_id) AS first_order_id
FROM orders
GROUP BY 1;


CREATE TEMPORARY TABLE orders_with_first_order_tag
SELECT
	orders.order_id,
    orders.user_id,
    orders.created_at,
    CASE WHEN first_order_id IS NOT NULL THEN 1 ELSE NULL END AS first_order_tag
FROM orders
	LEFT JOIN first_order_id_per_customer
		ON orders.order_id = first_order_id_per_customer.first_order_id;


CREATE TEMPORARY TABLE second_orders
SELECT
	user_id AS customer_id,
    MIN(order_id) AS second_order_id
FROM orders_with_first_order_tag
WHERE first_order_tag IS NULL
GROUP BY 1;

CREATE TEMPORARY TABLE orders_with_first_two_tags
SELECT
	order_id,
    user_id,
    created_at,
    first_order_tag,
    CASE WHEN second_order_id IS NOT NULL THEN 1 ELSE NULL END AS second_order_tag
FROM orders_with_first_order_tag
	LEFT JOIN second_orders
		ON orders_with_first_order_tag.order_id = second_orders.second_order_id;


CREATE TEMPORARY TABLE third_orders
SELECT
	user_id AS customer_id,
    MIN(order_id) AS third_order_id
FROM orders_with_first_two_tags
WHERE first_order_tag IS NULL AND second_order_tag IS NULL
GROUP BY 1;


CREATE TEMPORARY TABLE order_id_with_tags;
SELECT
	order_id,
    user_id AS customer_id,
    created_at,
    first_order_tag,
    second_order_tag,
    CASE WHEN third_order_id IS NOT NULL THEN 1 ELSE NULL END AS third_order_tag
FROM orders_with_first_two_tags
	LEFT JOIN third_orders
		ON orders_with_first_two_tags.order_id = third_orders.third_order_id;

CREATE TEMPORARY TABLE orders_with_sequence_id
SELECT
	order_id,
    customer_id,
    created_at,
    CASE
		WHEN first_order_tag = 1 THEN "1"
        WHEN second_order_tag = 1 THEN "2"
        WHEN third_order_tag = 1 THEN "3"
	ELSE NULL END AS order_sequence_id
FROM order_id_with_tags;

SELECT
	YEAR(created_at) AS year,
    COUNT(CASE WHEN order_sequence_id = 1 THEN order_id ELSE NULL END) AS first_orders,
    COUNT(CASE WHEN order_sequence_id = 2 THEN order_id ELSE NULL END) AS second_orders,
    COUNT(CASE WHEN order_sequence_id = 3 THEN order_id ELSE NULL END) AS third_orders
FROM orders_with_sequence_id
GROUP BY 1;


-- 6. Shown by year, what was the AOV of initial orders, as well as subsequent (2nd, 3rd, 4th, etc.) orders? 

SELECT
	YEAR(orders.created_at) AS year,
    AVG(CASE WHEN order_sequence_id = 1 THEN price_usd ELSE NULL END) AS first_order_AOV,
    AVG(CASE WHEN order_sequence_id = 2 THEN price_usd ELSE NULL END) AS second_order_AOV,
    AVG(CASE WHEN order_sequence_id = 3 THEN price_usd ELSE NULL END) AS third_order_AOV
FROM orders
	LEFT JOIN orders_with_sequence_id
		ON orders.order_id = orders_with_sequence_id.order_id
GROUP BY 1;


-- 7. What % of orders resulted in a refund? 

SELECT
	COUNT(DISTINCT order_item_refunds.order_id)/COUNT(DISTINCT orders.order_id) AS pct_orders_refunded
FROM orders
	LEFT JOIN order_item_refunds
		ON orders.order_id = order_item_refunds.order_id;

	
-- 8. How many customers received a refund on more than one order?

CREATE TEMPORARY TABLE refund_order_id
SELECT
	order_id AS refund_order_id,
	COUNT(DISTINCT order_item_refund_id) AS qty_items_refunded
FROM order_item_refunds
GROUP BY 1;

CREATE TEMPORARY TABLE orders_and_refunds_with_user
SELECT
	orders.order_id,
    user_id,
    qty_items_refunded,
    CASE WHEN refund_order_id IS NOT NULL THEN 1 ELSE NULL END AS refund_tag
FROM orders
	LEFT JOIN refund_order_id
		ON orders.order_id = refund_order_id.refund_order_id;

SELECT
	refunds AS refund_count,
    COUNT(DISTINCT user_id) AS customers
FROM (
SELECT
	user_id,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(refund_tag) AS refunds,
    SUM(qty_items_refunded) AS qty_items_refunded
FROM orders_and_refunds_with_user
GROUP BY 1) AS pre_aggregations
GROUP BY 1;


-- 9. On an order-item basis, what was the average refund rate, and how many customers had an above-average refund rate? 

SELECT
	COUNT(DISTINCT order_item_refund_id)/COUNT(DISTINCT orders.order_id) AS refund_rate
FROM orders
	LEFT JOIN order_item_refunds
		ON orders.order_id = order_item_refunds.order_id;
        

-- 10. How much more valuable is a customer that orders multiple times, as measured by total lifetime spend?  

SELECT
	CASE
		WHEN total_orders = 1 THEN '1 order'
        WHEN total_orders = 2 THEN '2 orders'
        WHEN total_orders = 3 THEN '3 orders'
    ELSE NULL END AS bucket,
    COUNT(DISTINCT customer_id) AS customers,
    AVG(lifetime_spend) AS avg_lifetime_spend
FROM (
SELECT
	orders_with_sequence_id.customer_id,
    MAX(order_sequence_id) AS total_orders,
    SUM(price_usd) AS lifetime_spend
FROM orders_with_sequence_id
	LEFT JOIN orders
		ON orders_with_sequence_id.order_id = orders.order_id
GROUP BY 1
) AS lifetime_spend_pre_pivot
GROUP BY 1;


/*
3. PRODUCT LINE ANALYSIS
    KEY QUESTIONS:
		1. What are the lifetime revenues, margin, and refund stats for each product? 
        2. When was a product first purchased standalone?
        3. What are the revenues, margin, and refund stats for each product shown by year?
        4. Expressed as a percentage of total returns, how much did each product contribute to total returns? 
        5. What are the monthly trends in revenue, margin, and refunds?
        6. How are the products distributed among the primary product designation in each order?
        7. Did the business sell any products as an add-on only, even for a limited amount of time?
        8. Which products experienced a change in price over the lifetime of the business?
        9. Which products have the highest margin? In the event of prices changing, show a trending view.
        10. What were the bounce rates for each of the product webpages through time? 
*/


-- 1. What are the lifetime revenues, margin, and refund stats for each product? 

SELECT
	CASE
		WHEN product_id = 1 THEN 'High Score Hoodie'
		WHEN product_id = 2 THEN 'PowerUp Pants'
		WHEN product _id = 3 THEN 'Cheatcode Cap'
		WHEN product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
	product_id,
    SUM(price_usd) AS revenue,
    SUM(price_usd)-SUM(cogs_usd) AS margin,
    SUM(refund_amount_usd) AS refund_volume
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
GROUP BY 1, 2;


-- 2. When was a product first purchased standalone? 

SELECT
	product_name,
    product_id,
    launch_date,
    first_standalone_order_date,
    DATEDIFF(first_standalone_order_date, launch_date) AS days_until_standalone_order
FROM (
SELECT
	CASE
		WHEN primary_product_id = 1 THEN 'High Score Hoodie'
		WHEN primary_product_id = 2 THEN 'PowerUp Pants'
		WHEN primary_product_id = 3 THEN 'Cheatcode Cap'
		WHEN primary_product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
	primary_product_id AS product_id,
    MIN(products.created_at) AS launch_date,
    MIN(orders.created_at) as first_standalone_order_date
FROM orders
	LEFT JOIN products
		ON orders.primary_product_id = products.product_id
WHERE items_purchased = 1
GROUP BY 1,2
) AS launch_first_solo_order_diff;

-- 3. What are the revenues, margin, and refund stats for each product shown by year?

SELECT
	YEAR(order_items.created_at) AS year,
    product_id,
	CASE
		WHEN product_id = 1 THEN 'High Score Hoodie'
		WHEN product_id = 2 THEN 'PowerUp Pants'
		WHEN product_id = 3 THEN 'Cheatcode Cap'
		WHEN product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
    SUM(price_usd) AS revenue,
    SUM(price_usd)-SUM(cogs_usd) AS margin,
    SUM(refund_amount_usd) AS refund_volume
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
GROUP BY 2,3,1
ORDER BY 2 ASC, 3 ASC, 1 ASC;


-- 4. Expressed as a percentage of total refund volume, how much did each product contribute to total refund losses? 

SELECT
	SUM(refund_amount_usd) AS total_refund_volume
FROM order_item_refunds;
	-- total refund volume = 85338.69

SELECT
    product_id,
	CASE
		WHEN product_id = 1 THEN 'High Score Hoodie'
		WHEN product_id = 2 THEN 'PowerUp Pants'
		WHEN product_id = 3 THEN 'Cheatcode Cap'
		WHEN product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
    (SUM(refund_amount_usd)/85338.69)*100 AS pct_refund_volume
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
GROUP BY 1, 2
ORDER BY 1 ASC, 2 ASC;

-- 5. Shown by product, what are the quarterly trends in revenue, margin, and refunds?

SELECT
	CASE
		WHEN product_id = 1 THEN 'High Score Hoodie'
		WHEN product_id = 2 THEN 'PowerUp Pants'
		WHEN product_id = 3 THEN 'Cheatcode Cap'
		WHEN product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
	YEAR(order_items.created_at) AS year,
    QUARTER(order_items.created_at) AS quarter,
    product_id,
    SUM(price_usd) AS revenue,
    SUM(price_usd)-SUM(cogs_usd) AS margin,
    SUM(refund_amount_usd) AS refund_volume
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
GROUP BY 4,2,3
ORDER BY 4 ASC, 2 ASC, 3 ASC;


-- 6. How are the products distributed among the primary product designation in each order?

SELECT
	primary_product_id,
    COUNT(DISTINCT order_id) AS order_count
FROM orders
GROUP BY 1;


-- 7. Shown by bucketed by product name, how many items were sold as an add-on? 

SELECT
	primary_product_id,
    CASE
		WHEN primary_product_id = 1 THEN 'High Score Hoodie'
		WHEN primary_product_id = 2 THEN 'PowerUp Pants'
		WHEN primary_product_id = 3 THEN 'Cheatcode Cap'
		WHEN primary_product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
    COUNT(DISTINCT order_item_id) added_on_to_orders
FROM orders
	LEFT JOIN order_items
		ON orders.order_id = order_items.order_id
        AND is_primary_item <> 1
WHERE items_purchased > 1
GROUP BY 1,2;

-- 8. Which products experienced a change in price over the lifetime of the business?

SELECT DISTINCT
	product_id,
    MIN(price_usd) AS lowest_price,
    MAX(price_usd) AS highest_price,
    MIN(cogs_usd) AS lowest_cogs,
    MAX(cogs_usd) AS highest_cogs
FROM order_items
GROUP BY 1;


-- 9. Which products have the highest margin? In the event of prices changing, show a trending view.

SELECT
	product_id,
    CASE
		WHEN product_id = 1 THEN 'High Score Hoodie'
		WHEN product_id = 2 THEN 'PowerUp Pants'
		WHEN product_id = 3 THEN 'Cheatcode Cap'
		WHEN product_id = 4 THEN 'Sidequest Shirt'
	ELSE NULL END AS product_name,
    SUM(price_usd)-SUM(cogs_usd) AS total_lifetime_margin,
    price_usd-cogs_usd AS per_item_margin
FROM order_items
GROUP BY 1,2,4;


-- 10. What were the bounce rates for each of the product webpages through time? 

CREATE TEMPORARY TABLE first_product_pageviews
SELECT
	first_product_pageview.website_session_id AS website_session_id,
    first_product_pageview_id,
    pageview_url
FROM (
SELECT
	website_session_id,
    MIN(website_pageview_id) AS first_product_pageview_id
FROM website_pageviews
WHERE pageview_url IN ('/high-score-hoodie','/power-up-pants','/cheat-code-cap','/side-quest-shirt','/cart')
GROUP BY 1) as first_product_pageview
	LEFT JOIN website_pageviews
		ON first_product_pageview.first_product_pageview_id = website_pageviews.website_pageview_id
WHERE pageview_url IN ('/high-score-hoodie','/power-up-pants','/cheat-code-cap','/side-quest-shirt','/cart');

CREATE TEMPORARY TABLE bounce_sessions
SELECT
	first_product_pageviews.website_session_id,
    first_product_pageviews.pageview_url,
    COUNT(DISTINCT website_pageviews.website_pageview_id) AS pageviews
FROM first_product_pageviews
	LEFT JOIN website_pageviews
		ON first_product_pageviews.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.pageview_url IN ('/high-score-hoodie','/power-up-pants','/cheat-code-cap','/side-quest-shirt','/cart')
GROUP BY 1,2
HAVING COUNT(DISTINCT website_pageviews.website_pageview_id) = 1;

SELECT
	CASE
		WHEN first_product_pageviews.pageview_url = '/high-score-hoodie' 
			THEN 1
		WHEN first_product_pageviews.pageview_url = '/power-up-pants' 
			THEN 2
		WHEN first_product_pageviews.pageview_url = '/cheat-code-cap' 
			THEN 3
		WHEN first_product_pageviews.pageview_url = '/side-quest-shirt' 
			THEN 4
	ELSE NULL END AS product_id,
	first_product_pageviews.pageview_url AS product_page,
    COUNT(DISTINCT bounce_sessions.website_session_id)
		/COUNT(DISTINCT first_product_pageviews.website_session_id)*100 AS bounce_rate
FROM first_product_pageviews
	LEFT JOIN bounce_sessions
		ON first_product_pageviews.website_session_id = bounce_sessions.website_session_id
GROUP BY 1,2
ORDER BY 1 ASC;



/*
4. WEBSITE ANALYSIS 
	1. How has website traffic trended throughout time?
	2. For every website page, when was it first visited, and how many lifetime visitors has it had? 
	3. Which pages were viewed to start a website session, and how was traffic distributed among them?
	4. How do the bounce rates of landing pages compare?
	5. Which landing pages, if any, were inactive towards the end of the business? 
	6. What is the distribution of total website traffic between paid and non -paid sources?
	7. How many different campaign types were there, and how did they perform, as revenue-drivers, through time?
	8. Which paid traffic sources drove the most traffic to the website?
	9. Shown by year and by month, what was the average rate of website visitors that completed a purchase?
	10. Shown by year and by month, how did funnel conversion rates across the website fare, on average? 
    */
    
-- 1. How has website traffic trended throughout time?

SELECT
	YEAR(created_at) AS year,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
GROUP BY 1;


-- 2. For every website page, when was it first visited, and how many lifetime visitors has it had? 

CREATE TEMPORARY TABLE first_pageviews
SELECT
	pageview_url,
    MIN(website_pageview_id) AS first_pageview_id,
    MIN(created_at) AS first_visited
FROM website_pageviews
GROUP BY 1
;

SELECT
	first_pageviews.pageview_url,
    first_pageview_id,
    first_visited,
    YEAR(first_visited) AS year_created,
    COUNT(DISTINCT website_pageview_id) AS pageviews
FROM first_pageviews
	LEFT JOIN website_pageviews
		ON website_pageviews.pageview_url = first_pageviews.pageview_url
GROUP BY 1,2,3
ORDER BY 3 ASC
;

-- 3. Which pages were viewed to start a website session, and how was traffic distributed among them?

SELECT
	pageview_url,
    COUNT(DISTINCT first_pageview_per_session_view.website_session_id) AS website_session_id
FROM (
SELECT
	website_session_id,
    MIN(website_pageview_id) AS first_pageview_id,
    MIN(created_at) AS first_pageview_visited
FROM website_pageviews 
GROUP BY 1
) AS first_pageview_per_session_view
	LEFT JOIN website_pageviews
		ON website_pageviews.website_pageview_id = first_pageview_per_session_view.first_pageview_id
GROUP BY 1
ORDER BY 2 DESC
;


-- 4. How many distinct webpages have acted as a landing page, and how did their bounce rates compare?

CREATE TEMPORARY TABLE landing_page_data
SELECT
	first_pageview_per_session_view.website_session_id AS website_session_id,
    first_pageview_id,
    first_pageview_visited,
    pageview_url
FROM (
SELECT
	website_session_id,
    MIN(website_pageview_id) AS first_pageview_id,
    MIN(created_at) AS first_pageview_visited
FROM website_pageviews 
GROUP BY 1
) AS first_pageview_per_session_view
	LEFT JOIN website_pageviews
		ON website_pageviews.website_pageview_id = first_pageview_per_session_view.first_pageview_id
;

SELECT DISTINCT
	pageview_url
FROM landing_page_data;
-- landing pages are ('/home','/lander-1','/lander-2','/lander-3','/lander-4','/lander-5')

CREATE TEMPORARY TABLE pageviews_per_website_session
SELECT
	first_pageview_per_session_view.website_session_id,
    first_pageview_id,
    COUNT(DISTINCT website_pageview_id) AS session_pageviews
FROM (
SELECT
	website_session_id,
    MIN(website_pageview_id) AS first_pageview_id
FROM website_pageviews
GROUP BY 1
) AS first_pageview_per_session_view
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = first_pageview_per_session_view.website_session_id
GROUP BY 1
;

SELECT
	pageview_url,
    COUNT(bounce_session) AS bounces,
    COUNT(DISTINCT website_session_id) AS sessions,
    (COUNT(bounce_session) / COUNT(DISTINCT website_session_id))*100 AS bounce_rate
FROM (
SELECT
	pageviews_per_website_session.website_session_id,
    first_pageview_id,
    pageview_url,
    session_pageviews,
    CASE WHEN session_pageviews = 1 THEN 1
    ELSE NULL END AS bounce_session
FROM pageviews_per_website_session
	LEFT JOIN website_pageviews
		ON pageviews_per_website_session.first_pageview_id = website_pageviews.website_pageview_id
) AS pre_calc_view    
GROUP BY 1
ORDER BY 2 DESC
;

-- 5. Which landing pages, if any, were inactive towards the end of the business data set? 

SELECT
	MAX(created_at) AS last_recorded_order
FROM orders
; -- as a frame of reference, the final order for the dataset is 03.19.2015

SELECT
	latest_pageview_per_lander.pageview_url,
    latest_pageview,
	CASE WHEN website_pageviews.created_at > '2015-03-01' THEN 'ACTIVE'
    ELSE 'INACTIVE' END AS status
FROM (
SELECT
	pageview_url,
    MAX(created_at) AS latest_pageview
FROM website_pageviews
WHERE pageview_url IN ('/home','/lander-1','/lander-2','/lander-3','/lander-4','/lander-5')
GROUP BY 1
) AS latest_pageview_per_lander
	LEFT JOIN website_pageviews
		ON latest_pageview_per_lander.latest_pageview = website_pageviews.created_at
ORDER BY 3 ASC
;


-- 6. What is the distribution of total website traffic between paid and non-paid sources?

SELECT DISTINCT
	utm_source, 
    utm_campaign,
    utm_content,
    device_type
FROM website_sessions
;

SELECT
	website_sessions,
    ((paid_sessions/website_sessions)*100) AS pct_paid_traffic,
    ((unpaid_sessions/website_sessions)*100) AS pct_unpaid_traffic
FROM (
SELECT
	COUNT(DISTINCT website_session_id) AS website_sessions,
    COUNT(CASE WHEN utm_source IS NOT NULL THEN 1
    ELSE NULL END) AS paid_sessions,
	COUNT(CASE WHEN utm_source IS  NULL THEN 1
    ELSE NULL END) AS unpaid_sessions
FROM website_sessions
) AS sessions_pct_paid_unpaid_precalc
;

-- 7. How many different campaign types were there, and how did they perform, as revenue-drivers, through time?
	

SELECT DISTINCT
	utm_campaign
FROM website_sessions;
-- 4 campaigns and a 5th bucket (null) for unpaid traffic

SELECT
	utm_campaign,
	CASE 
		WHEN YEAR(created_at) = 2012 THEN '2012'
		WHEN YEAR(created_at) = 2013 THEN '2013'
		WHEN YEAR(created_at) = 2014 THEN '2014'
		WHEN YEAR(created_at) = 2015 THEN '2015'
    ELSE NULL END AS year,
    COUNT(DISTINCT website_session_id) AS website_sessions
FROM website_sessions
GROUP BY 1,2
;


-- 8. Which paid traffic sources drove the most traffic to the website?

SELECT
	utm_source,
	COUNT(DISTINCT website_session_id) AS website_sessions
FROM website_sessions
WHERE utm_source IS NOT NULL
GROUP BY 1;


-- 9. Shown by year and by month, what was the average rate of website visitors that completed a purchase?

SELECT
	YEAR(website_sessions.created_at) AS year,
    MONTH(website_sessions.created_at) AS month,
    (COUNT(orders.website_session_id)
		/COUNT(website_sessions.website_session_id))*100 AS order_rate
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
;


-- 10. Shown by year and by month, how did funnel conversion rates across the website fare, on average?  

SELECT DISTINCT 
	pageview_url
FROM website_pageviews;

SELECT
	pageview_url,
	COUNT(DISTINCT website_pageview_id) AS pageviews
FROM website_pageviews
GROUP BY 1;

CREATE TEMPORARY TABLE traffic_funnel_precalc
SELECT
	first_pageviews.website_session_id,
    website_pageview_id,
    pageview_url
FROM (
SELECT
	website_session_id,
    MIN(website_pageview_id) AS first_pageview_id
FROM website_pageviews
GROUP BY 1
) AS first_pageviews
	LEFT JOIN website_pageviews
		ON first_pageviews.website_session_id = website_pageviews.website_session_id
;

SELECT
	year,
    month,
    lander_pvws,
    ((product_pvws/lander_pvws)*100) AS conversion2,
    product_pvws,
    ((cart_pvws/product_pvws)*100) AS conversion3,
    cart_pvws,
    ((shipping_pvws/cart_pvws)*100) AS conversion4,
    shipping_pvws,
    ((billing_pvws/shipping_pvws)*100) AS conversion5,
    billing_pvws,
    ((thanks_pvws/billing_pvws)*100) AS conversion6,
    thanks_pvws
FROM (

SELECT
    
    YEAR(website_sessions.created_at) AS year,
    MONTH(website_sessions.created_at) AS month,

	COUNT(CASE WHEN pageview_url IN 
		('/home','/lander-1','/lander-2','/lander-3','/lander-4','/lander-5') THEN 1
	ELSE NULL END) AS lander_pvws,
    
	COUNT(CASE WHEN pageview_url IN 
		('/products','/high-score-hoodie','/power-up-pants','/cheat-code-cap','/side-quest-shirt') THEN 1
	ELSE NULL END) AS product_pvws, 
    
	COUNT(CASE WHEN pageview_url = '/cart' THEN 1
	ELSE NULL END) AS cart_pvws,
    
    COUNT(CASE WHEN pageview_url = '/shipping' THEN 1
	ELSE NULL END) AS shipping_pvws,
    
	COUNT(CASE WHEN pageview_url IN ('/billing','/billing-2')  THEN 1
	ELSE NULL END) AS billing_pvws,
    
	COUNT(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1
	ELSE NULL END) AS thanks_pvws

FROM traffic_funnel_precalc
	LEFT JOIN website_sessions
		ON traffic_funnel_precalc.website_session_id = website_sessions.website_session_id
GROUP BY 1,2
) AS conversion_funnel_pageview_counts;
