-- E-Commerce Conversion Funnel Analysis
-- Source: Google Analytics 4 public sample e-commerce dataset
--
-- Purpose:
-- 1. Transform raw GA4 events into session-level funnel indicators
-- 2. Count sessions reaching each stage of the conversion funnel
-- 3. Prepare funnel data for visualization in Looker Studio


WITH events AS (

    -- Extract user, session, and event information from raw GA4 events
    SELECT
        user_pseudo_id

      -- Extract GA4 session ID from nested event parameters
      , (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS ga_session_id

      , event_name

    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    -- Exclude events that cannot be linked to a user
    WHERE user_pseudo_id IS NOT NULL

)

, sessions AS (

    -- Aggregate events to one row per user session
    SELECT
        user_pseudo_id
      , ga_session_id

      -- Identify sessions containing a product view
      , MAX(CASE
            WHEN event_name = 'view_item'
            THEN 1
            ELSE 0
        END) AS viewed_product

      -- Identify sessions where checkout was initiated
      , MAX(CASE
            WHEN event_name = 'begin_checkout'
            THEN 1
            ELSE 0
        END) AS began_checkout

      -- Identify sessions containing a purchase
      , MAX(CASE
            WHEN event_name = 'purchase'
            THEN 1
            ELSE 0
        END) AS purchased

    FROM events

    -- Keep only events assigned to a valid GA4 session
    WHERE ga_session_id IS NOT NULL

    GROUP BY
        user_pseudo_id
      , ga_session_id

)

, metrics AS (

    -- Calculate the number of sessions reaching each funnel stage
    SELECT
        COUNT(*) AS sessions
      , COUNTIF(viewed_product = 1) AS product_views
      , COUNTIF(began_checkout = 1) AS checkout
      , COUNTIF(purchased = 1) AS purchase

    FROM sessions

)

-- Reshape aggregated metrics into funnel stages for visualization
SELECT
    'Sessions' AS funnel_stage
  , 1 AS stage_order
  , sessions AS stage_value
FROM metrics

UNION ALL

SELECT
    'Product Views'
  , 2
  , product_views
FROM metrics

UNION ALL

SELECT
    'Checkout'
  , 3
  , checkout
FROM metrics

UNION ALL

SELECT
    'Purchase'
  , 4
  , purchase
FROM metrics

-- Preserve the intended funnel sequence
ORDER BY
    stage_order;
