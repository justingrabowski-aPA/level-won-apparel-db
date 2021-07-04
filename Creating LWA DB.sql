/* The purpose of this SQL file is to show the steps I took to modify a SQL database, 
for the purpose of supporting further SQL portfolio work on A Priori Analytica.

Originally named 'mavenfuzzyfactory', the schema came from the Advanced MySQL Data Analysis course from Maven Analytics. 
The schema included 6 tables for an e-commerce company that produced teddy bears. 

As part of developing my porfolio of analytical work, I decided to modify the database to change it to an apparel e-commerce company, 
which I named Level Won Apparel. 

Level Won Apparel sells lifestyle-themed clothing and accessories for video game fanatics. 

Below is how I turned mavenfuzzyfactory into levelwonapparel.
*/

/*
My Methodology:
	1. Create the new, empty schema and name it 'levelwonapparel'
	2. Search through the tables in 'mavenfuzzyfactory' to identify and change all values related to 'Maven Fuzzy Factory' 
		product names and branding
	3. Populate 'levelwonapparel' with the modified tables from 'mavenfuzzyfactory'
*/

-- STEP 1: 
-- CREATE SCHEMA `levelwonapparel` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- STEP 2:

USE mavenfuzzyfactory;

SELECT *
FROM products;

-- renaming first product 
UPDATE products
SET product_name = 'High Score Hoodie'
WHERE product_id = 1;

-- renaming second product
UPDATE products
SET product_name = 'PowerUp Pants'
WHERE product_id = 2;

-- renaming third product
UPDATE products
SET product_name = 'Cheatcode Cap'
WHERE product_id = 3;

-- renaming final product 
UPDATE products
SET product_name = 'Sidequest Shirt'
WHERE product_id = 4;

-- now that the products are renamed in the products table, check other tables: 

SELECT * 
FROM order_item_refunds;
-- order_item_refunds is good

SELECT *
FROM order_items;
-- order_items is good

SELECT *
FROM orders;
-- orders is also good

SELECT *
FROM website_pageviews;

-- ah, this one has specific pageview_url fields that need to be changed. let's do that 

-- first, I need to see all of the distinct pageview_url records

SELECT
pageview_url,
COUNT(DISTINCT website_pageview_id) AS pageview_count
FROM website_pageviews
GROUP BY 1
ORDER BY 2 DESC;

-- updating product 1 page url
UPDATE website_pageviews
SET pageview_url = '/high-score-hoodie'
WHERE pageview_url = '/the-original-mr-fuzzy';

-- updating product 2 page url
UPDATE website_pageviews
SET pageview_url = '/power-up-pants'
WHERE pageview_url = '/the-forever-love-bear';

-- updating product 3 page url
UPDATE website_pageviews
SET pageview_url = '/cheat-code-cap'
WHERE pageview_url = '/the-birthday-sugar-panda';

-- updating product 4 page url
UPDATE website_pageviews
SET pageview_url = '/side-quest-shirt'
WHERE pageview_url = '/the-hudson-river-mini-bear';

-- now all that's left is to port the tables, with updated records, over to the new schema 

-- STEP 3:

RENAME TABLE mavenfuzzyfactory.order_item_refunds TO levelwonapparel.order_item_refunds;

USE levelwonapparel;
SELECT *
FROM order_item_refunds;

-- looks like it was a success! now to port over the other tables 

USE mavenfuzzyfactory;

RENAME TABLE mavenfuzzyfactory.order_items TO levelwonapparel.order_items;
RENAME TABLE mavenfuzzyfactory.orders TO levelwonapparel.orders;
RENAME TABLE mavenfuzzyfactory.products TO levelwonapparel.products;
RENAME TABLE mavenfuzzyfactory.website_pageviews TO levelwonapparel.website_pageviews;
RENAME TABLE mavenfuzzyfactory.website_sessions TO levelwonapparel.website_sessions;

DROP SCHEMA mavenfuzzyfactory;

-- and that should do it, just have to remember to turn safe update mode back on. 
