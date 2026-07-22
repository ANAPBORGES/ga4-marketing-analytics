-- ============================================================
-- Query 4: New vs Returning Users
-- Project: GA4 Marketing Analytics (Google Merchandise Store)
-- Author: Ana Paula Borges | github.com/ANAPBORGES
-- ============================================================
-- Business question:
-- How many users each day are new vs returning, and how does the
-- returning share trend over the period?
--
-- Method: GA4 stamps every event with ga_session_number. A user is
-- treated as "new" on a day if their minimum session number that day
-- is 1 (their very first session), otherwise "returning". Using the
-- daily minimum avoids double-counting a user who crosses from session
-- 1 to 2 on the same day.

WITH user_day AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date)                                              AS dt,
    user_pseudo_id,
    MIN((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number')) AS min_session_number
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY dt, user_pseudo_id
)

SELECT
  dt,
  COUNT(*)                                                     AS active_users,
  COUNTIF(min_session_number = 1)                             AS new_users,
  COUNTIF(min_session_number > 1)                            AS returning_users,
  ROUND(COUNTIF(min_session_number > 1) / COUNT(*) * 100, 1) AS returning_pct
FROM user_day
GROUP BY dt
ORDER BY dt;
