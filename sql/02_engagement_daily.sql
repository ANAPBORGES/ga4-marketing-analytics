-- ============================================================
-- Query 2: Daily Engagement Overview
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- How do active users, sessions and engagement evolve day by day?
-- What is the engagement rate and average engagement time per session?
--
-- GA4 idioms: session = user_pseudo_id + ga_session_id; an engaged
-- session has session_engaged='1'; engagement_time_msec is per-event
-- engagement time (summed and divided by sessions for a per-session avg).

WITH e AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS dt,
    user_pseudo_id,
    event_name,
    CONCAT(user_pseudo_id, '-',
      CAST((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING)
    )                                                                                 AS session_key,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged')   AS session_engaged,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS eng_msec
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)

SELECT
  dt,
  COUNT(DISTINCT user_pseudo_id)                                          AS active_users,
  COUNT(DISTINCT session_key)                                             AS sessions,
  COUNT(DISTINCT IF(session_engaged = '1', session_key, NULL))           AS engaged_sessions,
  ROUND(COUNT(DISTINCT IF(session_engaged = '1', session_key, NULL))
        / COUNT(DISTINCT session_key) * 100, 1)                          AS engagement_rate_pct,
  ROUND(SUM(IFNULL(eng_msec, 0)) / 1000.0
        / COUNT(DISTINCT session_key), 1)                                AS avg_engagement_sec_per_session,
  ROUND(COUNT(*) / COUNT(DISTINCT session_key), 1)                       AS events_per_session,
  COUNTIF(event_name = 'purchase')                                       AS purchases
FROM e
GROUP BY dt
ORDER BY dt;
