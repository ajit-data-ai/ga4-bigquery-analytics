-- Conversion funnel mart: session → product_view → add_to_cart → checkout → purchase.
-- One row per date × channel_group with counts and drop-off rates at each stage.

WITH sessions AS (
    SELECT * FROM {{ ref('mart_sessions') }}
),

events AS (
    SELECT * FROM {{ ref('stg_ga4_events') }}
),

-- Count sessions that reached each funnel stage
funnel_counts AS (
    SELECT
        s.session_date                                      AS date,
        s.channel_group,

        COUNT(DISTINCT s.session_id)                        AS sessions,

        COUNT(DISTINCT CASE
            WHEN e.event_name = 'view_item' THEN s.session_id END)
                                                            AS product_views,

        COUNT(DISTINCT CASE
            WHEN e.event_name = 'add_to_cart' THEN s.session_id END)
                                                            AS add_to_cart,

        COUNT(DISTINCT CASE
            WHEN e.event_name = 'begin_checkout' THEN s.session_id END)
                                                            AS checkout_starts,

        COUNT(DISTINCT CASE
            WHEN e.event_name = 'purchase' THEN s.session_id END)
                                                            AS purchases,

        SUM(CASE WHEN e.event_name = 'purchase' THEN e.purchase_revenue ELSE 0 END)
                                                            AS revenue

    FROM sessions s
    LEFT JOIN events e
        ON s.user_pseudo_id = e.user_pseudo_id
       AND s.session_id     = e.session_id
    GROUP BY 1, 2
)

SELECT
    date,
    channel_group,
    sessions,
    product_views,
    add_to_cart,
    checkout_starts,
    purchases,
    ROUND(revenue, 2)                                       AS revenue_usd,

    -- Drop-off rates
    ROUND(product_views  * 100.0 / NULLIF(sessions, 0), 2)  AS view_rate_pct,
    ROUND(add_to_cart    * 100.0 / NULLIF(product_views, 0), 2) AS atc_rate_pct,
    ROUND(checkout_starts * 100.0 / NULLIF(add_to_cart, 0), 2)  AS checkout_rate_pct,
    ROUND(purchases      * 100.0 / NULLIF(checkout_starts, 0), 2) AS purchase_rate_pct,
    ROUND(purchases      * 100.0 / NULLIF(sessions, 0), 2)  AS overall_cvr_pct

FROM funnel_counts
ORDER BY date DESC, sessions DESC
