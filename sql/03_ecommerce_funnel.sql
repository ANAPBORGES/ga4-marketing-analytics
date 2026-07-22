-- ============================================================
-- Query 3: E-commerce Conversion Funnel
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- How do users flow through the purchase funnel
-- (view_item → add_to_cart → begin_checkout → purchase),
-- and where is the biggest drop-off?
--
-- Method: count DISTINCT users reaching each step, then compute
-- step-over-step and overall conversion with window functions.
-- Output is vertical (one row per step) so it feeds a funnel chart directly.

WITH step_users AS (
  SELECT
    COUNT(DISTINCT IF(event_name = 'view_item',      user_pseudo_id, NULL)) AS s1_view_item,
    COUNT(DISTINCT IF(event_name = 'add_to_cart',    user_pseudo_id, NULL)) AS s2_add_to_cart,
    COUNT(DISTINCT IF(event_name = 'begin_checkout', user_pseudo_id, NULL)) AS s3_begin_checkout,
    COUNT(DISTINCT IF(event_name = 'purchase',       user_pseudo_id, NULL)) AS s4_purchase
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

steps AS (
  SELECT 1 AS step_order, 'view_item'      AS step, s1_view_item      AS users FROM step_users
  UNION ALL SELECT 2, 'add_to_cart',    s2_add_to_cart    FROM step_users
  UNION ALL SELECT 3, 'begin_checkout', s3_begin_checkout FROM step_users
  UNION ALL SELECT 4, 'purchase',       s4_purchase       FROM step_users
)

SELECT
  step_order,
  step,
  users,
  -- Conversion from the top of the funnel
  ROUND(users / MAX(users) OVER () * 100, 1)                                    AS pct_of_top,
  -- Step-over-step conversion (vs previous step)
  ROUND(users / LAG(users) OVER (ORDER BY step_order) * 100, 1)                 AS pct_of_previous,
  -- Drop-off from the previous step
  LAG(users) OVER (ORDER BY step_order) - users                                AS dropoff_users
FROM steps
ORDER BY step_order;
