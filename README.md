# GA4 Marketing Analytics
> End-to-end **Google Analytics 4** analysis on the raw BigQuery export — acquisition channels, engagement, the e-commerce conversion funnel, device & geography, and revenue — handling GA4's nested event schema (`event_params`, `items`, `ecommerce`) with clean, reproducible SQL.

[![SQL](https://img.shields.io/badge/SQL-BigQuery-4285F4?style=flat&logo=google-cloud)](https://cloud.google.com/bigquery)
[![Data](https://img.shields.io/badge/Data-GA4%20export%20(public)-E37400?style=flat&logo=google-analytics)](https://console.cloud.google.com/marketplace/product/bigquery-public-data/ga4-obfuscated-sample-ecommerce)
[![Dashboard](https://img.shields.io/badge/Dashboard-Looker%20Studio-4285F4?style=flat&logo=google)](#dashboard)
[![Status](https://img.shields.io/badge/Status-SQL%20complete%20·%20dashboard%20in%20rebuild-yellow?style=flat)]()

---

## Business Context

**Industry:** E-commerce (Google Merchandise Store)
**Stakeholders:** Marketing, Growth, and E-commerce teams
**Business question:** *Where do our best users come from, how engaged are they, and where do we lose them on the path to purchase?*

This project analyzes the **GA4 → BigQuery export** of the Google Merchandise Store (Nov 2020 – Jan 2021, ~270K users). It reproduces the analyses a Marketing/Growth analyst runs daily in GA4 — acquisition by channel, engagement, the shopping funnel, conversion, and revenue — but **directly on the raw event data**, which is where the real depth (and the tricky nested schema) lives.

> **Why the raw export matters.** The GA4 UI is convenient but limited. Querying `event_params`, `items`, and `ecommerce` in BigQuery lets you define sessions, funnels, and channel groupings exactly, join to anything, and audit every number. Handling that nested structure well is a core GA4 analyst skill.

---

## Dataset

| Field | Details |
|---|---|
| **Source** | [`bigquery-public-data.ga4_obfuscated_sample_ecommerce`](https://console.cloud.google.com/marketplace/product/bigquery-public-data/ga4-obfuscated-sample-ecommerce) |
| **Grain** | One row per **event** (`page_view`, `view_item`, `add_to_cart`, `purchase`, …) |
| **Volume** | ~270K users · ~360K sessions · 4M+ events · US$362K revenue |
| **Period** | 1 Nov 2020 – 31 Jan 2021 (92 daily `events_*` tables) |

**GA4 concepts implemented in SQL:**
- **Session** = `user_pseudo_id` + `ga_session_id` (pulled from the nested `event_params`)
- **Engaged session** = `session_engaged = '1'`
- **Channel grouping** = derived from `traffic_source.medium` / `source`
- **Funnel** = distinct users reaching `view_item → add_to_cart → begin_checkout → purchase`
- **Revenue / products** = `ecommerce.purchase_revenue_in_usd` and the nested `items` array (UNNEST)

---

## SQL Queries

| Query | Description |
|---|---|
| [`01_traffic_acquisition.sql`](./sql/01_traffic_acquisition.sql) | Users, sessions, engagement, conversion and revenue **by channel** (GA4 channel grouping) |
| [`02_engagement_daily.sql`](./sql/02_engagement_daily.sql) | Daily active users, sessions, engagement rate, avg engagement time & events per session |
| [`03_ecommerce_funnel.sql`](./sql/03_ecommerce_funnel.sql) | Purchase funnel with step-over-step conversion and drop-off (vertical, chart-ready) |
| [`04_new_vs_returning_users.sql`](./sql/04_new_vs_returning_users.sql) | Daily new vs returning users via `ga_session_number` |
| [`05_ecommerce_performance.sql`](./sql/05_ecommerce_performance.sql) | Weekly revenue, transactions, AOV, items/order and WoW growth (LAG) |
| [`06_top_products.sql`](./sql/06_top_products.sql) | Top products by revenue from the nested `items` array + Pareto share |
| [`07_device_performance.sql`](./sql/07_device_performance.sql) | Desktop vs mobile vs tablet: traffic, engagement, conversion, revenue |
| [`08_geo_performance.sql`](./sql/08_geo_performance.sql) | Revenue and conversion by country + revenue concentration (Pareto) |

---

## Key Findings

1. **Scale & engagement** — 270K users and 360K sessions over 3 months, with a healthy **~67% engagement rate** across channels.
2. **Acquisition mix vs quality diverge** — *Organic Search* brings the most users (112K, US$104K revenue) but converts at only **1.18%**; **Referral** brings fewer users yet converts best at **1.85%** and the highest revenue per user (US$1.51). A classic "volume vs quality" trade-off for budget allocation.
3. **The funnel leaks hardest at the top** — of users who view an item, only **20.5% add to cart** (the single biggest drop-off). But once they begin checkout, **45.5% complete the purchase** — so the opportunity is upper-funnel (product page → cart), not checkout.
4. **Overall conversion 1.64%**, AOV **≈ US$64**, on US$362K total revenue.
5. **Mobile is nearly half the business** — Desktop drives **57.7%** of revenue and Mobile **40.5%**, at essentially the same conversion (~1.6%) — mobile UX is not a side channel.
6. **Revenue is geographically concentrated** — the **United States alone is 44%** of revenue; the top 3 markets (US, India, Canada) reach **63%**. Conversion is fairly uniform (~1.6–1.9%) across countries.
7. **Apparel-led, long-tail catalog** — hoodies, sweatshirts and fleece top the list; the top ~11 products account for only ~25% of revenue, a long tail rather than a few hero SKUs.

*All figures produced by the queries in [`/sql`](./sql), run live against the public GA4 export.*

---

## Dashboard

**Tool:** Looker Studio · connected to BigQuery via **custom queries** (nothing persisted, nothing expires).

> **Status: in rebuild.** Planned pages:

| Page | Content |
|---|---|
| **Acquisition** | Users/sessions/revenue by channel · engagement rate · conversion & revenue-per-user table |
| **Engagement** | Daily active users & sessions · engagement-rate trend · new vs returning |
| **Conversion Funnel** | view_item → add_to_cart → begin_checkout → purchase funnel + drop-off |
| **E-commerce** | Weekly revenue/AOV/transactions · top products (Pareto) |
| **Audience** | Device split · world map & top countries by revenue and conversion |

---

## How to Reproduce

No setup, no data upload — the GA4 export is public and hosted by Google:

1. Open the [BigQuery console](https://console.cloud.google.com/bigquery) (a free sandbox account works).
2. Copy any query from [`/sql`](./sql) and run it — it reads from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`.
3. For the dashboard, add each query as a **custom query** BigQuery source in Looker Studio.

---

## Repository Structure

```
ga4-marketing-analytics/
├── sql/                          ← 8 GA4 BigQuery queries (nested event_params/items, funnel, sessions)
├── looker_studio/
│   └── data_model.md             ← GA4 export structure, session/channel logic, query outputs
├── assets/                       ← dashboard previews (to be added)
└── README.md
```

---

## About

Built by **Ana Paula Borges** · [LinkedIn](https://linkedin.com/in/ana-paula-d-araújo-borges) · [GitHub](https://github.com/ANAPBORGES)

*Senior Data Analyst & Team Leader with 10+ years in BI, DataViz, and Marketing & Growth Analytics.*
