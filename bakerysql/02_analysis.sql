-- Q1. Revenue, profit and waste cost
SELECT ROUND(SUM(line_revenue), 2) AS revenue,
       ROUND(SUM(line_cost), 2)    AS cost_of_items_sold,
       ROUND(SUM(line_profit), 2)  AS profit_on_items_sold,
       (SELECT ROUND(SUM(waste_cost), 2) FROM daily_inventory) AS waste_cost,
       ROUND(SUM(line_profit) - (SELECT SUM(waste_cost) FROM daily_inventory), 2) AS profit_after_waste
FROM sales_clean;

-- Q2. Share of production unsold
SELECT SUM(units_produced) AS produced,
       SUM(units_sold)     AS sold,
       SUM(units_unsold)   AS unsold,
       ROUND(100.0 * SUM(units_unsold) / SUM(units_produced), 1) AS waste_pct
FROM daily_inventory;

-- Q3. Waste by category
SELECT category,
       ROUND(SUM(waste_cost), 2) AS waste_cost,
       ROUND(100.0 * SUM(waste_cost) / (SELECT SUM(waste_cost) FROM daily_inventory), 1) AS share_of_waste_pct,
       ROUND(100.0 * SUM(units_unsold) / SUM(units_produced), 1) AS waste_pct
FROM daily_inventory
GROUP BY category
ORDER BY waste_cost DESC;

-- Q4. Top 10 products by waste cost
SELECT product,
       category,
       perishability,
       ROUND(SUM(waste_cost), 2) AS waste_cost,
       ROUND(100.0 * SUM(waste_cost) / (SELECT SUM(waste_cost) FROM daily_inventory), 1) AS share_of_waste_pct,
       ROUND(100.0 * SUM(units_unsold) / SUM(units_produced), 1) AS waste_pct
FROM daily_inventory
GROUP BY product, category, perishability
ORDER BY waste_cost DESC
LIMIT 10;

-- Q5. Waste by store
SELECT i.store_id,
       s.revenue,
       s.profit_on_items_sold,
       ROUND(SUM(i.waste_cost), 2) AS waste_cost,
       ROUND(s.profit_on_items_sold - SUM(i.waste_cost), 2) AS profit_after_waste,
       ROUND(100.0 * SUM(i.units_unsold) / SUM(i.units_produced), 1) AS waste_pct
FROM daily_inventory i
JOIN (SELECT store_id,
             ROUND(SUM(line_revenue), 2) AS revenue,
             ROUND(SUM(line_profit), 2)  AS profit_on_items_sold
      FROM sales_clean
      GROUP BY store_id) s
  ON s.store_id = i.store_id
GROUP BY i.store_id
ORDER BY i.store_id;

-- Q6. Waste by day of week
SELECT CASE strftime('%w', inv_date)
         WHEN '0' THEN '0 Sun' WHEN '1' THEN '1 Mon' WHEN '2' THEN '2 Tue'
         WHEN '3' THEN '3 Wed' WHEN '4' THEN '4 Thu' WHEN '5' THEN '5 Fri'
         ELSE '6 Sat' END AS day_of_week,
       ROUND(SUM(waste_cost), 2) AS waste_cost,
       ROUND(100.0 * SUM(units_unsold) / SUM(units_produced), 1) AS waste_pct
FROM daily_inventory
GROUP BY day_of_week
ORDER BY day_of_week;

SELECT ROUND(100.0 * SUM(CASE WHEN strftime('%w', inv_date) IN ('0', '6') THEN waste_cost END)
             / SUM(waste_cost), 1) AS weekend_share_of_waste_pct
FROM daily_inventory;

-- Q7. Promotion vs full-price margin
SELECT discount_type,
       COUNT(*) AS order_lines,
       ROUND(100.0 * SUM(line_profit) / SUM(line_revenue), 1) AS margin_pct,
       ROUND(AVG(quantity), 2) AS avg_qty_per_line
FROM sales_clean
GROUP BY discount_type
ORDER BY margin_pct DESC;

-- Q8. Sensitivity check without flagged rows
SELECT ROUND(SUM(waste_cost), 2) AS waste_all_rows,
       ROUND(SUM(CASE WHEN flag_conflicting_production = 0 THEN waste_cost ELSE 0 END), 2) AS waste_without_flagged
FROM daily_inventory;

SELECT product, ROUND(SUM(waste_cost), 2) AS waste_cost
FROM daily_inventory
WHERE flag_conflicting_production = 0
GROUP BY product
ORDER BY waste_cost DESC
LIMIT 5;
