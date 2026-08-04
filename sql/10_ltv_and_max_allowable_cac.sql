-- ============================================================================
-- 10 - LTV, LTV:CAC, and the number that is actually actionable:
--      the maximum allowable CAC per channel.
--
-- Query 09 modelled what paid search WOULD cost at a benchmark CPC. This one
-- inverts the question, which is the version a growth team can act on:
--
--      "Given what a customer from this channel is worth,
--       what is the most we could afford to pay to acquire one?"
--
-- That number - max allowable CAC, or break-even bid - needs no cost data at
-- all. It comes from observed customer value and one declared margin. It is
-- the ceiling every bid, affiliate rate and partnership fee gets tested
-- against, and it is computable here where a real CAC is not.
--
-- WHAT IS MEASURED: purchasers, orders, revenue, repeat rate, value per
-- customer - all real, from the export.
-- WHAT IS ASSUMED: gross margin, and the payback multiple. Both declared below.
--
-- ---------------------------------------------------------------------------
-- THE WINDOW CAVEAT, WHICH IS NOT A FOOTNOTE.
--
-- This export covers 92 days. Ninety-two days of purchase history is an
-- OBSERVED value, not a lifetime value. Repeat rate is 17.54% inside the
-- window; the same cohort measured over a year would be higher, because
-- customers who bought once in January have not yet had the chance to buy
-- again.
--
-- So the figure below is deliberately named `value_92d`, never `ltv`. A true
-- LTV needs either a longer window or a retention curve extrapolated from
-- cohorts - and the honest move, when neither exists, is to report the horizon
-- in the column name. Every downstream ratio inherits that horizon and is
-- therefore CONSERVATIVE: the real ceiling is higher than what this returns.
-- ============================================================================

WITH
assumptions AS (
  SELECT
    0.35 AS gross_margin_pct,  -- merchandise gross margin
    1.0  AS payback_multiple   -- 1.0 = break-even. Use 3.0 for a 3:1 LTV:CAC target.
),

events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    traffic_source.medium AS medium,
    traffic_source.source AS source,
    event_name,
    ecommerce.purchase_revenue_in_usd AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

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
    END AS channel
  FROM events
),

-- One row per user, attributed to their FIRST-TOUCH channel.
--
-- First-touch, not last-touch: the question is what an ACQUIRED customer is
-- worth, so the channel that acquired them should own the value. Last-touch
-- would credit whichever channel happened to close a repeat order.
--
-- Implemented with an ordered aggregate on the earliest event, NOT ANY_VALUE.
-- ANY_VALUE would compile, run, and return a plausible table - while silently
-- picking an arbitrary channel per user. Attribution rules must be expressed
-- as an explicit ordering, or they are not attribution rules.
--
-- Consequence worth noting: each user is counted ONCE here, whereas query 09
-- counts a user under every channel they touched. That is why Paid Search
-- shows 13,414 users here and 15,528 there. Both are correct for their own
-- question; a dashboard that mixes them without saying so is not.
customer AS (
  SELECT
    user_pseudo_id,
    ARRAY_AGG(channel ORDER BY event_timestamp LIMIT 1)[OFFSET(0)] AS channel,
    COUNTIF(event_name = 'purchase')              AS orders,
    SUM(IF(event_name = 'purchase', revenue, 0))  AS revenue
  FROM classified
  GROUP BY user_pseudo_id
),

by_channel AS (
  SELECT
    channel,
    COUNT(*)                                      AS users,
    COUNTIF(orders > 0)                           AS customers,
    SUM(orders)                                   AS orders,
    SUM(revenue)                                  AS revenue,
    COUNTIF(orders > 1)                           AS repeat_customers
  FROM customer
  GROUP BY channel
)

SELECT
  c.channel,

  -- ---- MEASURED ----------------------------------------------------------
  c.users,
  c.customers,
  ROUND(SAFE_DIVIDE(c.customers, c.users) * 100, 2)          AS conversion_rate_pct,
  ROUND(SAFE_DIVIDE(c.orders, c.customers), 3)               AS orders_per_customer,
  ROUND(SAFE_DIVIDE(c.repeat_customers, c.customers) * 100, 2) AS repeat_rate_pct,
  ROUND(SAFE_DIVIDE(c.revenue, c.orders), 2)                 AS aov,

  -- Observed 92-day value per acquired customer. NOT lifetime value.
  ROUND(SAFE_DIVIDE(c.revenue, c.customers), 2)              AS value_92d,

  -- Gross-profit version. Revenue-based ratios flatter every channel by 1/margin.
  ROUND(SAFE_DIVIDE(c.revenue, c.customers) * a.gross_margin_pct, 2) AS gross_profit_92d,

  -- ---- THE ACTIONABLE NUMBER ---------------------------------------------
  -- Most we can pay per customer and still break even on 92-day gross profit.
  ROUND(SAFE_DIVIDE(c.revenue, c.customers) * a.gross_margin_pct
        / a.payback_multiple, 2)                             AS max_allowable_cac,

  -- Same ceiling expressed as a bid, by pushing it back through the channel's
  -- own conversion rate: what one VISITOR from this channel is worth. This is
  -- the number that goes into a bid strategy, and it is why a channel with
  -- great customer value but poor conversion still cannot be bought.
  ROUND(SAFE_DIVIDE(c.revenue, c.customers) * a.gross_margin_pct
        / a.payback_multiple
        * SAFE_DIVIDE(c.customers, c.users), 3)              AS max_allowable_cpc,

  -- ---- VERDICT vs the benchmark CPC of US$1.16 from query 09 --------------
  ROUND(SAFE_DIVIDE(c.revenue, c.customers) * a.gross_margin_pct
        / a.payback_multiple
        * SAFE_DIVIDE(c.customers, c.users) / 1.16, 2)       AS headroom_vs_benchmark_cpc

FROM by_channel c
CROSS JOIN assumptions a
WHERE c.customers > 0
ORDER BY max_allowable_cpc DESC;
