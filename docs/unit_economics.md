# Unit economics: CAC, LTV, ROAS — and what this data can honestly support

Queries [`09`](../sql/09_paid_media_economics.sql) and [`10`](../sql/10_ltv_and_max_allowable_cac.sql) add the growth-economics layer: CPC, CPA, CAC, CTR, ROAS, ROI, LTV and LTV:CAC.

**The GA4 export contains no cost data.** No spend, no impressions, no billed clicks — those live in Google Ads, and this public sample has no Ads linkage. So this document starts by separating what is measured from what is assumed, and the queries carry that separation into their column names.

---

## Measured vs modelled

| Measured — real, from the export | Modelled — from declared inputs |
|---|---|
| Users, sessions, purchases, purchasers | Spend, CPC, CTR, impressions |
| Revenue, AOV, conversion rate | CPA, CAC, ROAS, ROI |
| Orders per customer, repeat rate | — |
| 92-day value per customer | — |

Every modelled column in query 09 is prefixed **`m_`**. The prefix exists so that no one skimming the output can mistake a scenario input for an observation.

### Declared inputs

| Input | Value | Source |
|---|---|---|
| `cpc_usd` | US$1.16 | Industry reference, US retail paid search |
| `ctr` | 3.11% | Industry reference, same segment |
| `gross_margin_pct` | 35% | Merchandise gross margin assumption |
| `payback_multiple` | 1.0 | 1.0 = break-even. Set 3.0 for a 3:1 LTV:CAC target |

They sit in a `benchmark` / `assumptions` CTE at the top of each query. Change one value, and everything downstream moves — which is what makes it a model rather than a claim.

---

## Three definitions that get conflated

**CPA is not CAC.** CPA is cost per purchase *event*; CAC is cost per acquired *customer*. They differ by orders per buyer — 1.29 here, so CAC runs ~29% above CPA. Reporting one under the other's name understates acquisition cost by that margin.

**ROAS is not ROI.** ROAS is revenue per unit spend; ROI is profit per unit spend. At a 35% margin, break-even is **2.86x ROAS** — so a campaign at 2.0x ROAS, which reads like a success, is destroying money. Query 09 returns both, side by side, for exactly this reason.

**92-day value is not LTV.** The export covers 92 days. Repeat rate is 17.54% *within that window*; customers who bought in January have not yet had a chance to buy again. The column is therefore named `value_92d`, never `ltv`. Every ratio built on it inherits the horizon and is **conservative** — the true ceiling is higher than what these queries return. A real LTV needs a longer window or a retention curve extrapolated from cohorts, and when neither exists, the honest move is to put the horizon in the column name.

---

## A quarter of the traffic cannot be attributed

This sample is privacy-obfuscated. Two buckets are **not channels** and are labelled so:

| Bucket | Users | What it is |
|---|---:|---|
| `ZZ - unattributable (obfuscated)` | 51,038 | `medium = '<Other>'` — source masked by the sample |
| `ZZ - consent withheld` | 17,948 | `medium = '(data deleted)'` — deletion request honoured |

Together, roughly **a quarter of all users have an unknowable acquisition source**. Folding them into a generic "Other" channel would silently manufacture the third-largest revenue line in the report. They are excluded from any cost model, because there is no cost per acquisition for traffic you cannot attribute.

**Do not read the consent-withheld bucket as a channel insight.** It shows a 7.2% conversion rate against a 1.6% site average. That is a selection effect — people who have transacted have more reason to file a deletion request — not a discovery about a traffic source.

---

## The number that is actually actionable

A real CAC is not computable here. **Maximum allowable CAC** is, and it is the more useful number anyway:

```
max_allowable_cac = value_92d × gross_margin / payback_multiple
max_allowable_cpc = max_allowable_cac × conversion_rate
```

It needs no cost data — only observed customer value and one declared margin. It is the ceiling every bid, affiliate rate and partnership fee gets tested against.

### Results (35% margin, break-even, 92-day horizon)

| Channel | Customers | Conv. | Repeat | Value 92d | Max CAC | **Max CPC** | vs US$1.16 benchmark |
|---|---:|---:|---:|---:|---:|---:|---:|
| Referral | 744 | 1.86% | 19.76% | US$83.43 | US$29.20 | **US$0.543** | 0.47x |
| Direct | 1,011 | 1.58% | 17.90% | US$82.83 | US$28.99 | **US$0.457** | 0.39x |
| Paid Search | 218 | 1.53% | 16.97% | US$84.04 | US$29.41 | **US$0.449** | 0.39x |
| Organic Search | 1,557 | 1.53% | 16.51% | US$79.49 | US$27.82 | **US$0.426** | 0.37x |

**No channel can afford the benchmark CPC.** The best of them, Referral, supports US$0.54 against a market rate of US$1.16 — 47%. Modelled at that CPC, paid search returns **0.50x ROAS and −82.5% ROI**.

That is not a verdict on paid search. It is a statement about the horizon: at 92 days and a 35% margin, this business cannot buy traffic at market rates. The levers are a longer payback window (a true LTV would raise every ceiling), a higher margin, or better conversion — and the model makes each of those testable by changing one number at the top of the query.

---

## The bug that changed the answer

Query 10 attributes each user to one channel. The first implementation used `ANY_VALUE(channel)`.

It compiled, ran, and returned an entirely plausible table. It also picked an **arbitrary** channel per multi-touch user. Replacing it with an explicit ordered aggregate on the earliest event —

```sql
ARRAY_AGG(channel ORDER BY event_timestamp LIMIT 1)[OFFSET(0)]
```

— moved the results materially:

| Paid Search | with `ANY_VALUE` | with first-touch |
|---|---:|---:|
| Conversion rate | 1.07% | **1.53%** |
| AOV | US$51.24 | **US$68.88** |
| Value 92d | US$57.33 | **US$84.04** |
| Max allowable CPC | US$0.214 | **US$0.449** |

The arbitrary version made paid search look like the worst channel in the account by a wide margin. Corrected, it sits level with organic and direct. A budget decision taken on the first table would have cut a channel that was performing at parity.

**Attribution rules must be expressed as an explicit ordering, or they are not attribution rules.** Nothing in the output of the broken version looked wrong.

---

## Why the two queries disagree on user counts

Query 09 counts a user under **every** channel they touched (Paid Search: 15,528). Query 10 counts each user **once**, under first touch (Paid Search: 14,282).

Both are correct for their own question — 09 asks "how much traffic did this channel deliver", 10 asks "how many customers did this channel acquire". A dashboard that puts them on the same page without saying so is not.
