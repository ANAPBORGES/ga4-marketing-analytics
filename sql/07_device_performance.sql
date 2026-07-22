-- ============================================================
-- Query 7: Performance by Device Category
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- How do desktop, mobile and tablet compare on traffic, engagement
-- and conversion? Where should UX/effort be prioritized?

WITH events AS (
  SELECT
    device.category AS device_category,
    user_pseudo_id,
    event_name,
    CONCAT(user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    )                                                                                 AS session_key,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged')   AS session_engaged,
    ecommerce.purchase_revenue_in_usd                                                 AS purchase_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)

SELECT
  device_category,
  COUNT(DISTINCT user_pseudo_id)                                                 AS users,
  COUNT(DISTINCT session_key)                                                    AS sessions,
  ROUND(COUNT(DISTINCT IF(session_engaged = '1', session_key, NULL))
        / COUNT(DISTINCT session_key) * 100, 1)                                  AS engagement_rate_pct,
  COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL))              AS purchasers,
  ROUND(COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL))
        / COUNT(DISTINCT user_pseudo_id) * 100, 2)                               AS user_conv_rate_pct,
  ROUND(SUM(IF(event_name = 'purchase', purchase_revenue, 0)), 2)              AS revenue,
  ROUND(SUM(IF(event_name = 'purchase', purchase_revenue, 0))
        / SUM(SUM(IF(event_name = 'purchase', purchase_revenue, 0))) OVER () * 100, 1) AS revenue_share_pct
FROM events
GROUP BY device_category
ORDER BY revenue DESC;
