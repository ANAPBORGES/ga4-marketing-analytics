# Data Model & GA4 Query Notes

## Source

```
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*   (Google public dataset — never expires)
   │  grain: one row per EVENT; one daily table per day (events_YYYYMMDD), 2020-11-01 → 2021-01-31
   │
   │  key nested fields:
   │    event_params  ARRAY<STRUCT<key, value STRUCT<string_value,int_value,float_value,double_value>>>
   │    items         ARRAY<STRUCT<item_name, item_category, quantity, item_revenue_in_usd, ...>>
   │    ecommerce     STRUCT<purchase_revenue_in_usd, transaction_id, total_item_quantity, ...>
   │    traffic_source STRUCT<medium, source, name>   device STRUCT<category,...>   geo STRUCT<country,...>
   ▼
   8 analytical queries  →  Looker Studio (custom queries, 5 pages)
```

> **No persisted views.** In a BigQuery sandbox any table/view expires after 60 days, so Looker Studio connects to each `.sql` as a **custom query**. The query files are the single source of truth.

---

## GA4 patterns used

**Reading a nested event parameter** — GA4 stores per-event params in an array; pull one with a scalar subquery:
```sql
(SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'ga_session_id')        AS session_id
(SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_engaged')       AS session_engaged
(SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'engagement_time_msec')  AS eng_msec
```

**Session key** — GA4 has no session row; a session is a user + its session id:
```sql
CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING))
```

**Engaged session** — `session_engaged = '1'`. Engagement rate = engaged sessions ÷ sessions.

**Channel grouping** — derived from `traffic_source` (this dataset's real values):

| medium / source | Channel |
|---|---|
| `organic` | Organic Search |
| `cpc` | Paid Search |
| `referral` | Referral |
| `(none)` / `(direct)` | Direct |
| `(data deleted)` | Data deleted (privacy) |
| everything else | Other |

**Funnel** — count DISTINCT `user_pseudo_id` firing each step event, then window functions for step-over-step and top-of-funnel conversion:
`view_item → add_to_cart → begin_checkout → purchase`.

**Products & revenue** — purchase revenue from `ecommerce.purchase_revenue_in_usd` on `purchase` events; product detail from `UNNEST(items)` (`item_revenue_in_usd`, `quantity`).

---

## Query outputs (for dashboard binding)

| Query | Grain | Key columns |
|---|---|---|
| 01 traffic_acquisition | channel | users, sessions, engaged_sessions, engagement_rate_pct, purchases, revenue, user_conv_rate_pct, revenue_per_user |
| 02 engagement_daily | day | active_users, sessions, engagement_rate_pct, avg_engagement_sec_per_session, events_per_session, purchases |
| 03 ecommerce_funnel | step | step_order, step, users, pct_of_top, pct_of_previous, dropoff_users |
| 04 new_vs_returning_users | day | active_users, new_users, returning_users, returning_pct |
| 05 ecommerce_performance | week | transactions, purchasers, revenue, aov, items_per_order, wow_growth_pct |
| 06 top_products | product | units_sold, transactions, revenue, revenue_rank, revenue_share_pct, cumulative_share_pct |
| 07 device_performance | device_category | users, sessions, engagement_rate_pct, purchasers, user_conv_rate_pct, revenue, revenue_share_pct |
| 08 geo_performance | country | users, purchasers, revenue, user_conv_rate_pct, revenue_rank, revenue_share_pct, cumulative_share_pct |

---

## Headline numbers (live)

270K users · 360K sessions · 1.64% conversion · US$362K revenue · ~US$64 AOV · 67% engagement rate.
Channels: Organic Search largest (volume) · Referral best conversion (1.85%).
Funnel: view→cart 20.5% (biggest drop) · checkout→purchase 45.5% · view→purchase 7.2%.
Device: Desktop 57.7% · Mobile 40.5% · Tablet 1.8%. Geo: US 44% · top 3 = 63%.
