-- Session-grain mart from GA4 events.
-- One row per user × session, with engagement and acquisition attributes.

WITH events AS (
    SELECT * FROM {{ ref('stg_ga4_events') }}
),

session_base AS (
    SELECT
        user_pseudo_id,
        session_id,
        MIN(event_dt)                                           AS session_date,
        MIN(event_ts)                                           AS session_start_ts,
        MAX(event_ts)                                           AS session_end_ts,
        TIMESTAMP_DIFF(MAX(event_ts), MIN(event_ts), SECOND)    AS session_duration_seconds,

        -- Traffic source (from first event in session)
        MAX(traffic_source) IGNORE NULLS                        AS traffic_source,
        MAX(traffic_medium) IGNORE NULLS                        AS traffic_medium,
        MAX(traffic_name) IGNORE NULLS                          AS traffic_campaign,

        -- Device & geo
        MAX(device_category) IGNORE NULLS                      AS device_category,
        MAX(country) IGNORE NULLS                               AS country,

        -- Engagement signals
        MAX(CASE WHEN session_engaged = '1' THEN 1 ELSE 0 END)  AS is_engaged,
        COUNTIF(event_name = 'page_view')                       AS pageviews,
        COUNTIF(event_name = 'scroll')                          AS scroll_events,
        COUNTIF(event_name = 'click')                           AS click_events,

        -- Conversion signals
        COUNTIF(event_name = 'purchase')                        AS purchases,
        SUM(CASE WHEN event_name = 'purchase' THEN purchase_revenue ELSE 0 END) AS revenue,
        COUNTIF(event_name = 'add_to_cart')                     AS add_to_cart_events,
        COUNTIF(event_name = 'begin_checkout')                  AS checkout_starts

    FROM events
    GROUP BY user_pseudo_id, session_id
)

SELECT
    *,
    purchases > 0                                               AS converted,
    CASE
        WHEN traffic_medium IN ('cpc', 'ppc', 'paid')          THEN 'paid_search'
        WHEN traffic_medium = 'organic'                         THEN 'organic_search'
        WHEN traffic_medium IN ('social', 'social-network')     THEN 'social'
        WHEN traffic_medium = 'email'                           THEN 'email'
        WHEN traffic_medium = 'referral'                        THEN 'referral'
        WHEN traffic_source = '(direct)'                        THEN 'direct'
        ELSE 'other'
    END                                                         AS channel_group

FROM session_base
