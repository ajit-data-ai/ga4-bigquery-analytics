-- Flattens the GA4 BigQuery export event table.
-- GA4 exports one row per event; params are stored as REPEATED STRUCTs.
-- This model extracts the most commonly needed params into flat columns.

WITH source AS (
    SELECT * FROM {{ source('ga4', 'events_*') }}
    WHERE _TABLE_SUFFIX >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL {{ var('lookback_days', 90) }} DAY))
),

extracted AS (
    SELECT
        event_date,
        PARSE_DATE('%Y%m%d', event_date)                AS event_dt,
        event_timestamp,
        TIMESTAMP_MICROS(event_timestamp)               AS event_ts,
        event_name,
        user_pseudo_id,
        user_id,
        stream_id,
        platform,

        -- Session-level params
        (SELECT value.int_value FROM UNNEST(event_params)
         WHERE key = 'ga_session_id')                   AS session_id,
        (SELECT value.int_value FROM UNNEST(event_params)
         WHERE key = 'ga_session_number')               AS session_number,
        (SELECT value.string_value FROM UNNEST(event_params)
         WHERE key = 'session_engaged')                 AS session_engaged,

        -- Traffic source
        traffic_source.name                             AS traffic_name,
        traffic_source.medium                           AS traffic_medium,
        traffic_source.source                           AS traffic_source,

        -- Page params
        (SELECT value.string_value FROM UNNEST(event_params)
         WHERE key = 'page_location')                   AS page_location,
        (SELECT value.string_value FROM UNNEST(event_params)
         WHERE key = 'page_title')                      AS page_title,

        -- E-commerce
        ecommerce.purchase_revenue                      AS purchase_revenue,
        ecommerce.transaction_id                        AS transaction_id,

        -- Device
        device.category                                 AS device_category,
        device.operating_system                         AS os,
        device.browser                                  AS browser,

        -- Geo
        geo.country                                     AS country,
        geo.region                                      AS region,
        geo.city                                        AS city

    FROM source
),

deduped AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id, session_id, event_name, event_timestamp
            ORDER BY event_timestamp
        ) AS row_num
    FROM extracted
)

SELECT * EXCEPT (row_num) FROM deduped WHERE row_num = 1
