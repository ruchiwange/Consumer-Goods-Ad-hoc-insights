-- Consumer Goods Ad-hoc Insights project:

show databases;
use gdb023;
 -- 1.  Provide the list of markets in which customer  "Atliq  Exclusive"  operates its business in the  APAC  region. 
SELECT DISTINCT market FROM dim_customer 
WHERE customer="Atliq Exclusive" AND region = 'APAC';

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The 
-- final output contains these fields, 
-- unique_products_2020 
-- unique_products_2021 
-- percentage_chg 
WITH product_count AS (
    SELECT 
        fiscal_year,
        COUNT(DISTINCT product_code) AS unique_product_count
    FROM fact_gross_price
    GROUP BY fiscal_year
)
SELECT 
    p2020.unique_product_count AS unique_products_2020,
    p2021.unique_product_count AS unique_products_2021,
    ROUND(
        (p2021.unique_product_count - p2020.unique_product_count) 
        / p2020.unique_product_count * 100, 2
    ) AS pct_change
FROM 
    product_count p2020
CROSS JOIN
    product_count p2021
WHERE
    p2020.fiscal_year = 2020 
    AND p2021.fiscal_year = 2021;


-- 3.Provide a report with all the unique product counts for each  segment  and 
-- sort them in descending order of product counts. The final output contains 2 fields, 
-- segment 
-- product_count 
SELECT segment,COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4.  Follow-up: Which segment had the most increase in unique products in 
-- 2021 vs 2020? The final output contains these fields,
-- segment 
-- product_count_2020
-- product_count_2021 
-- difference
WITH segment_products AS (
    SELECT 
        p.segment,
        s.fiscal_year,
        COUNT(DISTINCT s.product_code) AS unique_product_count
    FROM fact_sales_monthly s
    JOIN dim_product p 
        ON s.product_code = p.product_code
    GROUP BY p.segment, s.fiscal_year
)
SELECT
    sp2020.segment,
    sp2020.unique_product_count AS product_count_2020,
    sp2021.unique_product_count AS product_count_2021,
    sp2021.unique_product_count - sp2020.unique_product_count AS difference
FROM segment_products sp2020
JOIN segment_products sp2021
    ON sp2020.segment = sp2021.segment
   AND sp2020.fiscal_year = 2020
   AND sp2021.fiscal_year = 2021
ORDER BY difference DESC;

   
-- 5.  Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, 
-- product_code 
-- product 
-- manufacturing_cost 
SELECT 
    mc.product_code,
    CONCAT(p.product, ' (', p.variant, ')') AS product,
    mc.cost_year,
    mc.manufacturing_cost
FROM fact_manufacturing_cost mc
JOIN dim_product p 
    ON p.product_code = mc.product_code
WHERE mc.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
   OR mc.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY mc.manufacturing_cost DESC;

-- 6.  Generate a report which contains the top 5 customers who received an 
-- average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
-- Indian  market. The final output contains these fields, 
-- customer_code 
-- customer 
-- average_discount_percentage
SELECT 
    cust.customer_code,
    cust.customer,
    ROUND(AVG(ded.pre_invoice_discount_pct), 3) AS average_discount_percentage
FROM fact_pre_invoice_deductions ded
JOIN dim_customer cust 
    ON cust.customer_code = ded.customer_code
WHERE cust.market = 'India' 
  AND ded.fiscal_year = 2021
GROUP BY cust.customer_code, cust.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- 7.  Get the complete report of the Gross sales amount for the customer  “Atliq 
-- Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
-- high-performing months and take strategic decisions. 
-- The final report contains these columns: 
-- Month 
-- Year 
-- Gross sales Amount
WITH sales_data AS (
    SELECT 
        c.customer,
        MONTHNAME(s.date) AS month_name,
        MONTH(s.date) AS month_number,
        YEAR(s.date) AS year,
        (s.sold_quantity * g.gross_price) AS gross_sales
    FROM fact_sales_monthly s
    JOIN fact_gross_price g 
        ON g.product_code = s.product_code
    JOIN dim_customer c 
        ON c.customer_code = s.customer_code
    WHERE c.customer = 'Atliq Exclusive'
)
SELECT 
    month_name AS month,
    year,
    CONCAT(ROUND(SUM(gross_sales) / 1000000, 2), 'M') AS gross_sales_amount
FROM sales_data
GROUP BY year, month_name, month_number
ORDER BY year, month_number;

    
-- 8.  In which quarter of 2020, got the maximum total_sold_quantity? The final 
-- output contains these fields sorted by the total_sold_quantity, 
-- Quarter 
-- total_sold_quantity
WITH sales_quarter AS (
    SELECT 
        s.date,
        s.sold_quantity,
        CASE 
            WHEN MONTH(s.date) IN (9, 10, 11)  THEN 'Q1'
            WHEN MONTH(s.date) IN (12, 1, 2)   THEN 'Q2'
            WHEN MONTH(s.date) IN (3, 4, 5)    THEN 'Q3'
            ELSE 'Q4'
        END AS quarter
    FROM fact_sales_monthly s
    WHERE s.fiscal_year = 2020
)
SELECT 
    quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM sales_quarter
GROUP BY quarter
ORDER BY total_sold_quantity DESC;

    
-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 
-- and the percentage of contribution?  The final output  contains these fields, 
-- channel 
-- gross_sales_mln 
-- percentage 
WITH channel_sales AS (
    SELECT 
        cust.channel,
        ROUND(SUM(sales.sold_quantity * gp.gross_price) / 1000000, 2) AS gross_sales_mln
    FROM dim_customer cust
    JOIN fact_sales_monthly sales 
        ON cust.customer_code = sales.customer_code
    JOIN fact_gross_price gp 
        ON gp.product_code = sales.product_code
       AND gp.fiscal_year = sales.fiscal_year 
    WHERE sales.fiscal_year = 2021 
    GROUP BY cust.channel
)
SELECT 
    channel,
    gross_sales_mln,
    CONCAT(
        ROUND(gross_sales_mln * 100 / SUM(gross_sales_mln) OVER (), 2),
        '%'
    ) AS percentage
FROM channel_sales
ORDER BY gross_sales_mln DESC;

-- 10.Get the Top 3 products in each division that have a high 
-- total_sold_quantity in the fiscal_year 2021? The final output contains these 
-- fields, 
-- division 
-- product_code
WITH product_rank AS (
    SELECT 
        p.division,
        s.product_code, 
        CONCAT(p.product, ' (', p.variant, ')') AS product,
        SUM(s.sold_quantity) AS total_sold_quantity,
        RANK() OVER (
            PARTITION BY p.division 
            ORDER BY SUM(s.sold_quantity) DESC
        ) AS rank_order
    FROM fact_sales_monthly s
    JOIN dim_product p 
        ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, s.product_code, p.product, p.variant
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM product_rank
WHERE rank_order <= 3
ORDER BY division, rank_order;


