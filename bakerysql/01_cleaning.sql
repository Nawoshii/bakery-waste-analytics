-- STEP 1: Profile raw data
-- 1a. Row count
SELECT COUNT(*) AS total_rows FROM raw_sales;

-- 1b. Blank values
SELECT
  SUM(CASE WHEN Festival       IS NULL OR TRIM(Festival)       = '' THEN 1 ELSE 0 END) AS blank_festival,
  SUM(CASE WHEN Promotion_Type IS NULL OR TRIM(Promotion_Type) = '' THEN 1 ELSE 0 END) AS blank_promo_type
FROM raw_sales;

-- 1c. Duplicates
SELECT Order_ID, Product, COUNT(*) AS n
FROM raw_sales
GROUP BY Order_ID, Product
HAVING COUNT(*) > 1;

-- 1d. Time format
SELECT LENGTH(Time) AS time_length, COUNT(*) AS n
FROM raw_sales GROUP BY LENGTH(Time);


-- STEP 2: Verify calculated columns
-- 2a. Selling price
SELECT COUNT(*) AS bad_selling_price
FROM raw_sales
WHERE ABS(ROUND(Unit_Price * (1 - Discount_Percentage / 100.0), 2) - Selling_Price) > 0.02;

-- 2b. Total bill
SELECT COUNT(*) AS bad_total_bill
FROM raw_sales
WHERE ABS(ROUND(Selling_Price * Quantity, 2) - Total_Bill) > 0.05;

-- 2c. Profit
SELECT COUNT(*) AS bad_profit
FROM raw_sales
WHERE ABS(ROUND((Selling_Price - Cost_Price) * Quantity, 2) - Profit) > 0.05;

-- 2d. Dates
SELECT COUNT(*) AS bad_dates
FROM raw_sales
WHERE CAST(strftime('%Y', Date) AS INTEGER) <> CAST(Year  AS INTEGER)
   OR CAST(strftime('%m', Date) AS INTEGER) <> CAST(Month AS INTEGER)
   OR CAST(strftime('%d', Date) AS INTEGER) <> CAST(Day   AS INTEGER);


-- STEP 3: Find logic problems
-- 3a. Discount without promotion
SELECT COUNT(*) AS discount_without_promo,
       ROUND(AVG(CAST(Discount_Percentage AS REAL)), 1) AS avg_discount_pct
FROM raw_sales
WHERE Promotion_Applied = 'No' AND CAST(Discount_Percentage AS REAL) > 0;

-- 3b. Sold below cost
SELECT Order_ID, Product, Unit_Price, Cost_Price, Discount_Percentage, Selling_Price, Profit
FROM raw_sales
WHERE CAST(Profit AS REAL) < 0;

-- 3c. Large quantities
SELECT CAST(Quantity AS INTEGER) AS qty, COUNT(*) AS n
FROM raw_sales
WHERE CAST(Quantity AS INTEGER) > 10
GROUP BY qty ORDER BY qty;

-- 3d. Inventory repeated per order
SELECT Date, Store_ID, Product,
       COUNT(*)          AS order_lines,
       SUM(CAST(Quantity AS INTEGER))       AS total_qty_ordered,
       MIN(CAST(Units_Sold AS INTEGER))     AS units_sold_min,
       MAX(CAST(Units_Sold AS INTEGER))     AS units_sold_max,
       MIN(CAST(Units_Produced AS INTEGER)) AS produced_min,
       MAX(CAST(Units_Produced AS INTEGER)) AS produced_max
FROM raw_sales
GROUP BY Date, Store_ID, Product
HAVING COUNT(*) > 1
LIMIT 20;

-- 3e. Conflicting production
SELECT COUNT(*) AS conflicting_groups
FROM (
  SELECT Date, Store_ID, Product
  FROM raw_sales
  GROUP BY Date, Store_ID, Product
  HAVING MIN(CAST(Units_Produced AS INTEGER)) <> MAX(CAST(Units_Produced AS INTEGER))
);


-- STEP 4: Build sales_clean
DROP TABLE IF EXISTS sales_clean;

CREATE TABLE sales_clean AS
SELECT
  TRIM(Order_ID)     AS order_id,
  TRIM(Customer_ID)  AS customer_id,
  TRIM(Store_ID)     AS store_id,

  CAST(Customer_Age AS INTEGER)  AS customer_age,
  Customer_Gender                AS customer_gender,
  Customer_Segment               AS customer_segment,
  CASE WHEN Loyalty_Member = 'Yes' THEN 1 ELSE 0 END AS is_loyalty_member,

  DATE(Date)                         AS order_date,
  CAST(Year  AS INTEGER)             AS year,
  CAST(Month AS INTEGER)             AS month,
  strftime('%Y-%m', Date)            AS year_month,
  Day_of_Week                        AS day_of_week,
  CASE WHEN Weekend = 'Yes' THEN 1 ELSE 0 END AS is_weekend,
  CAST(Hour AS INTEGER)              AS hour,
  SUBSTR('0' || TRIM(Time), -5)      AS order_time,
  CASE
    WHEN CAST(Hour AS INTEGER) < 11 THEN 'Morning'
    WHEN CAST(Hour AS INTEGER) < 15 THEN 'Midday'
    WHEN CAST(Hour AS INTEGER) < 18 THEN 'Afternoon'
    ELSE 'Evening'
  END                                AS daypart,

  Season                              AS season,
  COALESCE(NULLIF(TRIM(Festival), ''), 'None') AS festival,
  CASE WHEN NULLIF(TRIM(Festival), '') IS NULL THEN 0 ELSE 1 END AS is_festival_day,
  Weather                             AS weather,
  CAST(Temperature AS REAL)           AS temperature_c,

  Product                             AS product,
  Category                            AS category,
  Storage_Type                        AS storage_type,
  Perishability                       AS perishability,

  CAST(Quantity            AS INTEGER) AS quantity,
  CAST(Unit_Price          AS REAL)    AS unit_price,
  CAST(Cost_Price          AS REAL)    AS cost_price,
  CAST(Discount_Percentage AS REAL)    AS discount_pct,
  CAST(Selling_Price       AS REAL)    AS selling_price,
  CAST(Total_Bill          AS REAL)    AS line_revenue,
  CAST(Profit              AS REAL)    AS line_profit,
  ROUND(CAST(Cost_Price AS REAL) * CAST(Quantity AS INTEGER), 2) AS line_cost,
  Payment_Method                       AS payment_method,

  CASE WHEN Promotion_Applied = 'Yes' THEN 1 ELSE 0 END AS is_promotion,
  COALESCE(NULLIF(TRIM(Promotion_Type), ''), 'None')     AS promotion_type,
  CASE
    WHEN Promotion_Applied = 'Yes'            THEN 'Promotion'
    WHEN CAST(Discount_Percentage AS REAL) > 0 THEN 'Unlabeled discount'
    ELSE 'Full price'
  END                                                    AS discount_type,

  CAST(Customer_Rating AS INTEGER) AS customer_rating,

  CASE WHEN CAST(Profit AS REAL) < 0       THEN 1 ELSE 0 END AS flag_sold_below_cost,
  CASE WHEN CAST(Quantity AS INTEGER) > 10 THEN 1 ELSE 0 END AS flag_bulk_quantity
FROM raw_sales;


-- STEP 5: Build daily_inventory
DROP TABLE IF EXISTS daily_inventory;

CREATE TABLE daily_inventory AS
SELECT
  DATE(Date)                         AS inv_date,
  strftime('%Y-%m', Date)            AS year_month,
  Store_ID                           AS store_id,
  Product                            AS product,
  Category                           AS category,
  Perishability                      AS perishability,
  MAX(CAST(Units_Produced AS INTEGER))                              AS units_produced,
  MAX(CAST(Units_Sold     AS INTEGER))                              AS units_sold,
  MAX(CAST(Units_Produced AS INTEGER)) - MAX(CAST(Units_Sold AS INTEGER)) AS units_unsold,
  ROUND(100.0 * (MAX(CAST(Units_Produced AS INTEGER)) - MAX(CAST(Units_Sold AS INTEGER)))
        / MAX(CAST(Units_Produced AS INTEGER)), 1)                  AS waste_pct,
  ROUND(AVG(CAST(Cost_Price AS REAL)), 2)                           AS avg_unit_cost,
  CASE WHEN MIN(CAST(Units_Produced AS INTEGER)) <> MAX(CAST(Units_Produced AS INTEGER))
       THEN 1 ELSE 0 END                                            AS flag_conflicting_production
FROM raw_sales
GROUP BY DATE(Date), Store_ID, Product;

ALTER TABLE daily_inventory ADD COLUMN waste_cost REAL;
UPDATE daily_inventory SET waste_cost = ROUND(units_unsold * avg_unit_cost, 2);


-- STEP 6: Check clean tables
-- 6a. Row count
SELECT COUNT(*) AS clean_rows FROM sales_clean;

-- 6b. Revenue match
SELECT (SELECT ROUND(SUM(Total_Bill), 2) FROM raw_sales)   AS raw_revenue,
       (SELECT ROUND(SUM(line_revenue), 2) FROM sales_clean) AS clean_revenue;

-- 6c. Remaining blanks
SELECT SUM(festival = '') + SUM(promotion_type = '') AS remaining_blanks FROM sales_clean;

-- 6d. Time format
SELECT LENGTH(order_time) AS len, COUNT(*) FROM sales_clean GROUP BY 1;

-- 6e. Inventory match
SELECT COUNT(*) AS inventory_mismatches
FROM daily_inventory i
JOIN (SELECT order_date, store_id, product, SUM(quantity) AS q
      FROM sales_clean GROUP BY 1, 2, 3) s
  ON s.order_date = i.inv_date AND s.store_id = i.store_id AND s.product = i.product
WHERE s.q <> i.units_sold;

-- 6f. Flag summary
SELECT 'Unlabeled discounts'        AS issue, COUNT(*) FROM sales_clean WHERE discount_type = 'Unlabeled discount'
UNION ALL SELECT 'Sold below cost',          COUNT(*) FROM sales_clean WHERE flag_sold_below_cost = 1
UNION ALL SELECT 'Bulk quantity (>10)',      COUNT(*) FROM sales_clean WHERE flag_bulk_quantity = 1
UNION ALL SELECT 'Conflicting production',   COUNT(*) FROM daily_inventory WHERE flag_conflicting_production = 1;
