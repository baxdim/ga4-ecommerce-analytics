-- Weekly E-Commerce KPI Analysis
-- Source: Google Analytics 4 public sample e-commerce dataset
--
-- Purpose:
-- 1. Build session-level behavioral flags from raw GA4 events
-- 2. Calculate weekly traffic, conversion, purchasing users, and revenue KPIs
-- 3. Prepare aggregated data for visualization in Looker Studio


WITH events AS (

    -- Extract the key fields required for session-level analysis
    SELECT
        PARSE_DATE('%Y%m%d', event_date) AS event_date
      , user_pseudo_id

      -- Extract GA4 session ID from nested event parameters
      , (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id

      , event_name
      , ecommerce.purchase_revenue AS purchase_revenue

    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    -- Exclude events that cannot be linked to a user
    WHERE user_pseudo_id IS NOT NULL

)

, sessions AS (

    -- Aggregate raw events to one row per user session
    SELECT
        user_pseudo_id
      , ga_session_id

      -- Use the earliest event date as the session date
      , MIN(event_date) AS session_date

      -- Flag sessions containing a product view
      , MAX(CASE
            WHEN event_name = 'view_item'
            THEN 1
            ELSE 0
        END) AS viewed_product

      -- Flag sessions where checkout was initiated
      , MAX(CASE
            WHEN event_name = 'begin_checkout'
            THEN 1
            ELSE 0
        END) AS began_checkout

      -- Flag sessions containing a purchase
      , MAX(CASE
            WHEN event_name = 'purchase'
            THEN 1
            ELSE 0
        END) AS purchased

      -- Sum purchase revenue generated within each session
      , SUM(CASE
            WHEN event_name = 'purchase'
            THEN COALESCE(purchase_revenue, 0)
            ELSE 0
        END) AS revenue

    FROM events

    -- Keep only events that can be assigned to a GA4 session
    WHERE ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id
      , ga_session_id

)

SELECT

    -- Aggregate session metrics by calendar week, starting on Monday
    DATE_TRUNC(
        session_date
      , WEEK(MONDAY)
    ) AS week

    -- Total number of sessions
  , COUNT(*) AS sessions

    -- Sessions containing at least one product view
  , COUNTIF(
        viewed_product = 1
    ) AS product_view_sessions

    -- Sessions where checkout was initiated
  , COUNTIF(
        began_checkout = 1
    ) AS checkout_sessions

    -- Sessions containing a purchase
  , COUNTIF(
        purchased = 1
    ) AS purchase_sessions

    -- Unique users who completed at least one purchase
  , COUNT(
        DISTINCT CASE
            WHEN purchased = 1
            THEN user_pseudo_id
        END
    ) AS purchasing_users

    -- Total weekly purchase revenue
  , ROUND(
        SUM(revenue)
      , 2
    ) AS total_revenue

    -- Share of sessions that resulted in a purchase
  , ROUND(
        COUNTIF(purchased = 1)
        / COUNT(*) * 100
      , 2
    ) AS purchase_session_rate_pct

FROM sessions

GROUP BY
    week

ORDER BY
    week;
