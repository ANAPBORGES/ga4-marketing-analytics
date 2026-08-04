-- ============================================================================
-- 09 - Paid media economics: CPC, CPA, CAC, ROAS and CTR.
--
-- THE HONEST CONSTRAINT, STATED FIRST.
--
-- The GA4 export contains no cost data. None. There is no spend, no
-- impressions, no clicks-as-billed - those live in Google Ads, and this public
-- sample has no Ads linkage. So CPC, CPA, CAC, CTR and ROAS cannot be measured
-- from this source. They can only be MODELLED.
--
-- This query therefore does two separate things, kept visibly separate:
--
--   MEASURED  - sessions, purchases, purchasers, revenue, conversion rate.
--               Real numbers, straight from the export.
--   MODELLED  - spend, CPC, CTR, impressions, and every metric derived from
--               them. Driven by the declared benchmark block below.
--
-- Every modelled column is prefixed `m_`. That prefix is the point: a reader
-- who skims this output must not be able to mistake a scenario input for an
-- observation. Portfolio work that quietly invents a spend column and reports
-- ROAS as fact is the thing this file is built to not be.
--
-- Only ONE channel here is genuinely paid: medium = 'cpc' (Paid Search,
-- 15,527 users). The model is applied to it and to nothing else. The unpaid
-- channels get their real economics reported instead - and query 10 asks the
-- planning question that actually applies to them.
-- ============================================================================

WITH
-- ---------------------------------------------------------------------------
-- SCENARIO INPUTS. Change these; everything modelled moves. They are industry
-- reference points for US retail search, not measurements of this business.
-- ---------------------------------------------------------------------------
benchmark AS (
  SELECT
    1.16  AS cpc_usd,          -- average CPC, US retail paid search
    0.0311 AS ctr,             -- 3.11% average CTR, same segment
    0.35  AS gross_margin_pct  -- merchandise gross margin
),

events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
    traffic_source.medium AS medium,
    traffic_source.source AS source,
    event_name,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

-- ---------------------------------------------------------------------------
-- Channel grouping. Note the two buckets that are NOT channels.
--
-- This sample is privacy-obfuscated: 51,037 users carry medium '<Other>' and
-- 17,948 carry '(data deleted)'. Together that is roughly a quarter of all
-- users whose acquisition source is unknowable. Folding them into an "Other"
-- channel would silently create the third-largest revenue source in the
-- report. They are named for what they are, and excluded from any cost model,
-- because you cannot compute a cost per acquisition for traffic you cannot
-- attribute.
-- ---------------------------------------------------------------------------
classified AS (
  SELECT
    *,
    CASE
      WHEN medium = 'cpc'                          THEN 'Paid Search'
      WHEN medium = 'organic'                      THEN 'Organic Search'
      WHEN medium = 'referral'                     THEN 'Referral'
      WHEN medium = '(none)' OR source = '(direct)' THEN 'Direct'
      WHEN medium = '(data deleted)'               THEN 'ZZ - consent withheld'
      ELSE                                              'ZZ - unattributable (obfuscated)'
    END AS channel,
    medium = 'cpc' AS is_paid
  FROM events
),

measured AS (
  SELECT
    channel,
    LOGICAL_OR(is_paid)                                                   AS is_paid,
    COUNT(DISTINCT user_pseudo_id)                                        AS users,
    COUNT(DISTINCT CONCAT(user_pseudo_id, CAST(session_id AS STRING)))    AS sessions,
    COUNTIF(event_name = 'purchase')                                      AS purchases,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL))     AS purchasers,
    SUM(IF(event_name = 'purchase', revenue, 0))                          AS revenue
  FROM classified
  GROUP BY channel
)

SELECT
  m.channel,

  -- ---- MEASURED ----------------------------------------------------------
  m.users,
  m.sessions,
  m.purchases,
  m.purchasers,
  ROUND(m.revenue, 0)                                        AS revenue,
  ROUND(SAFE_DIVIDE(m.purchasers, m.users) * 100, 2)         AS conversion_rate_pct,
  ROUND(SAFE_DIVIDE(m.revenue, m.purchases), 2)              AS aov,
  ROUND(SAFE_DIVIDE(m.revenue, m.users), 2)                  AS revenue_per_user,

  -- ---- MODELLED (paid channel only) --------------------------------------
  -- Spend is sessions x CPC. Sessions stand in for billable clicks: one paid
  -- click starts one session, minus bounces the export cannot distinguish, so
  -- this UNDERSTATES clicks and therefore understates spend. Direction of the
  -- bias is stated because an unstated bias is a lie by omission.
  IF(m.is_paid, ROUND(m.sessions * b.cpc_usd, 0), NULL)      AS m_spend,
  IF(m.is_paid, b.cpc_usd, NULL)                             AS m_cpc,

  -- Impressions implied by the benchmark CTR - the top of the funnel the
  -- export cannot see at all.
  IF(m.is_paid, ROUND(SAFE_DIVIDE(m.sessions, b.ctr), 0), NULL) AS m_impressions,
  IF(m.is_paid, ROUND(b.ctr * 100, 2), NULL)                 AS m_ctr_pct,

  -- CPA is per purchase EVENT; CAC is per acquired CUSTOMER. They are not
  -- synonyms and they differ by orders per buyer - here 1.29, so CAC runs
  -- ~29% above CPA. Reporting one under the other's name is the most common
  -- error in growth reporting.
  IF(m.is_paid, ROUND(SAFE_DIVIDE(m.sessions * b.cpc_usd, m.purchases), 2), NULL)  AS m_cpa,
  IF(m.is_paid, ROUND(SAFE_DIVIDE(m.sessions * b.cpc_usd, m.purchasers), 2), NULL) AS m_cac,

  -- ROAS is revenue per unit spend. ROI is profit per unit spend, and they
  -- diverge by the gross margin - a campaign at 2.0x ROAS on a 35% margin is
  -- destroying money, which the ROAS number alone will never show.
  IF(m.is_paid, ROUND(SAFE_DIVIDE(m.revenue, m.sessions * b.cpc_usd), 2), NULL) AS m_roas,
  IF(m.is_paid, ROUND(
       SAFE_DIVIDE(m.revenue * b.gross_margin_pct - m.sessions * b.cpc_usd,
                   m.sessions * b.cpc_usd) * 100, 1), NULL)  AS m_roi_pct

FROM measured m
CROSS JOIN benchmark b
ORDER BY m.channel;
