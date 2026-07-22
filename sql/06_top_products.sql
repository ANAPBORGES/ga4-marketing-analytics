-- ============================================================
-- Query 6: Top Products by Revenue
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Which products drive the most revenue and units, and how does
-- revenue concentrate across the catalog (Pareto)?
--
-- The purchased products live in the nested `items` array on 'purchase'
-- events, so we UNNEST it. item_revenue_in_usd is the line revenue.

WITH item_sales AS (
  SELECT
    it.item_name                       AS product,
    it.item_category                   AS category,
    it.quantity                        AS quantity,
    it.item_revenue_in_usd             AS item_revenue,
    ecommerce.transaction_id           AS transaction_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
       UNNEST(items) AS it
  WHERE event_name = 'purchase'
),

product_totals AS (
  SELECT
    product,
    ANY_VALUE(category)                        AS category,
    SUM(quantity)                              AS units_sold,
    COUNT(DISTINCT transaction_id)             AS transactions,
    ROUND(SUM(item_revenue), 2)                AS revenue
  FROM item_sales
  GROUP BY product
)

SELECT
  product,
  category,
  units_sold,
  transactions,
  revenue,
  RANK() OVER (ORDER BY revenue DESC)                                             AS revenue_rank,
  ROUND(revenue / SUM(revenue) OVER () * 100, 2)                                  AS revenue_share_pct,
  ROUND(
    SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    / SUM(revenue) OVER () * 100, 1
  )                                                                              AS cumulative_share_pct
FROM product_totals
ORDER BY revenue DESC
LIMIT 25;
