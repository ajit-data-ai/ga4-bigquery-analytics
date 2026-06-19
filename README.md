# GA4 BigQuery Analytics

dbt project that transforms Google Analytics 4 BigQuery exports into clean session, funnel, and channel attribution models. Gives e-commerce and SaaS teams a reliable source of truth for traffic, engagement, and conversion reporting — without needing Looker or GA4's own reporting UI.

## Architecture

```
GA4 → BigQuery export (native, enabled in GA4 Admin)
    │
    └── analytics_XXXXXXXX.events_YYYYMMDD (raw event tables)
              │
              ▼
         stg_ga4_events  (flatten params, deduplicate)
              │
              ├── mart_sessions      (session grain: source, device, engagement)
              ├── mart_funnel        (funnel: view → cart → checkout → purchase)
              └── mart_channel_ltv   (channel × cohort LTV over 30/60/90 days)
```

## Models

| Model | Grain | Key columns |
|---|---|---|
| `stg_ga4_events` | 1 row per event | `user_pseudo_id`, `session_id`, `event_name`, `page_location`, `purchase_revenue` |
| `mart_sessions` | 1 row per user × session | `channel_group`, `device_category`, `is_engaged`, `pageviews`, `converted`, `revenue` |
| `mart_funnel` | 1 row per date × channel | `sessions → product_views → add_to_cart → checkout → purchase` + drop-off rates |

## Quick Start

```bash
# 1. Enable GA4 BigQuery export in GA4 Admin → BigQuery Linking
# 2. Note your BigQuery project and dataset (analytics_XXXXXXXX)

pip install dbt-bigquery

# profiles.yml
# ga4_analytics:
#   target: prod
#   outputs:
#     prod:
#       type: bigquery
#       project: my-gcp-project
#       dataset: ga4_marts
#       method: oauth
#       threads: 4

dbt deps
dbt run --select staging
dbt run --select marts
dbt test
```

## Flattening GA4 event params

GA4 stores event parameters as a REPEATED STRUCT (`event_params`). The staging model uses `UNNEST` + subqueries to extract the most common params into flat columns:

```sql
(SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location
```

Add additional params by following this pattern in `stg_ga4_events.sql`.

## Common GA4 event names

| Event | What it tracks |
|---|---|
| `page_view` | Page loaded |
| `session_start` | New session began |
| `view_item` | Product detail page |
| `add_to_cart` | Item added to cart |
| `begin_checkout` | Checkout started |
| `purchase` | Transaction completed |
| `scroll` | 90% scroll depth |
