-- ============================================================
-- Query 8: Performance by Country
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Which countries drive the most users and revenue, how concentrated
-- is the audience, and which markets convert best?

WITH events AS (
  SELECT
    geo.country AS country,
    user_pseudo_id,
    event_name,
    ecommerce.purchase_revenue_in_usd AS purchase_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

country_totals AS (
  SELECT
    country,
    COUNT(DISTINCT user_pseudo_id)                                    AS users,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS purchasers,
    ROUND(SUM(IF(event_name = 'purchase', purchase_revenue, 0)), 2)  AS revenue
  FROM events
  GROUP BY country
)

SELECT
  country,
  users,
  purchasers,
  revenue,
  ROUND(purchasers / NULLIF(users, 0) * 100, 2)                                 AS user_conv_rate_pct,
  RANK() OVER (ORDER BY revenue DESC)                                           AS revenue_rank,
  ROUND(revenue / SUM(revenue) OVER () * 100, 1)                                AS revenue_share_pct,
  ROUND(
    SUM(revenue) OVER (ORDER BY revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    / SUM(revenue) OVER () * 100, 1
  )                                                                             AS cumulative_share_pct
FROM country_totals
WHERE users > 0
ORDER BY revenue DESC
LIMIT 20;
