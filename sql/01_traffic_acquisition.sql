-- ============================================================
-- Query 1: Traffic Acquisition by Channel
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- Which acquisition channels bring the most users and sessions,
-- how engaged are they, and which ones actually convert to revenue?
--
-- Source: bigquery-public-data.ga4_obfuscated_sample_ecommerce (GA4 export).
-- GA4 idioms used here:
--   - a session = user_pseudo_id + ga_session_id (from event_params)
--   - an engaged session has session_engaged = '1'
--   - traffic_source is the user's acquisition source (first touch)

WITH events AS (
  SELECT
    user_pseudo_id,
    event_name,
    CONCAT(user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    )                                                                              AS session_key,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged') AS session_engaged,
    ecommerce.purchase_revenue_in_usd                                             AS purchase_revenue,
    -- GA4-style default channel grouping (simplified to this dataset's values)
    CASE
      WHEN traffic_source.medium = 'organic'            THEN 'Organic Search'
      WHEN traffic_source.medium = 'cpc'                THEN 'Paid Search'
      WHEN traffic_source.medium = 'referral'           THEN 'Referral'
      WHEN traffic_source.medium IN ('(none)', '(direct)')
        OR traffic_source.source = '(direct)'           THEN 'Direct'
      WHEN traffic_source.medium = 'email'              THEN 'Email'
      WHEN traffic_source.medium = '(data deleted)'     THEN 'Data deleted (privacy)'
      ELSE 'Other'
    END                                                                            AS channel
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)

SELECT
  channel,
  COUNT(DISTINCT user_pseudo_id)                                                  AS users,
  COUNT(DISTINCT session_key)                                                     AS sessions,
  COUNT(DISTINCT IF(session_engaged = '1', session_key, NULL))                    AS engaged_sessions,
  ROUND(COUNT(DISTINCT IF(session_engaged = '1', session_key, NULL))
        / COUNT(DISTINCT session_key) * 100, 1)                                   AS engagement_rate_pct,
  COUNTIF(event_name = 'purchase')                                               AS purchases,
  ROUND(SUM(IF(event_name = 'purchase', purchase_revenue, 0)), 2)               AS revenue,
  -- User conversion rate = purchasing users / all users in the channel
  ROUND(COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL))
        / COUNT(DISTINCT user_pseudo_id) * 100, 2)                               AS user_conv_rate_pct,
  ROUND(SUM(IF(event_name = 'purchase', purchase_revenue, 0))
        / NULLIF(COUNT(DISTINCT user_pseudo_id), 0), 2)                          AS revenue_per_user
FROM events
GROUP BY channel
ORDER BY revenue DESC;
