-- ============================================================
-- Query 5: E-commerce Performance (weekly)
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- How is revenue trending week over week? What are transactions,
-- average order value (AOV), items per order, and WoW growth?
--
-- Purchase-level metrics come from the ecommerce.* record on
-- 'purchase' events. Weeks start on Monday.

WITH purchases AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', event_date), WEEK(MONDAY)) AS week_start,
    ecommerce.transaction_id                                  AS transaction_id,
    user_pseudo_id,
    ecommerce.purchase_revenue_in_usd                         AS revenue,
    ecommerce.total_item_quantity                             AS items
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
),

weekly AS (
  SELECT
    week_start,
    COUNT(DISTINCT transaction_id)                            AS transactions,
    COUNT(DISTINCT user_pseudo_id)                            AS purchasers,
    ROUND(SUM(revenue), 2)                                    AS revenue,
    ROUND(SUM(revenue) / NULLIF(COUNT(DISTINCT transaction_id), 0), 2) AS aov,
    ROUND(SUM(items)   / NULLIF(COUNT(DISTINCT transaction_id), 0), 1) AS items_per_order
  FROM purchases
  GROUP BY week_start
)

SELECT
  week_start,
  transactions,
  purchasers,
  revenue,
  aov,
  items_per_order,
  LAG(revenue) OVER (ORDER BY week_start)                     AS prev_week_revenue,
  ROUND(
    (revenue - LAG(revenue) OVER (ORDER BY week_start))
    / NULLIF(LAG(revenue) OVER (ORDER BY week_start), 0) * 100, 1
  )                                                           AS wow_growth_pct
FROM weekly
ORDER BY week_start;
