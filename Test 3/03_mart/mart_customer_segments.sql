-- =============================================================================
-- Model  : mart_customer_segments
-- Layer  : Mart
-- Sources: int_customer_metrics, int_orders_enriched
--
-- Purpose:
--   Segments all customers into business-meaningful groups based on their
--   purchase recency and frequency. Used by Senior Managers to understand
--   customer base composition and target retention/re-engagement campaigns.
--
-- Segmentation Business Logic (documented):
-- ┌──────────────┬──────────────────────────────────────────────────────────┐
-- │ Segment      │ Definition                                               │
-- ├──────────────┼──────────────────────────────────────────────────────────┤
-- │ new          │ Exactly 1 order ever                                     │
-- │ returning    │ 2+ orders AND last order within 180 days of dataset max  │
-- │ at_risk      │ 2+ orders AND last order 181–365 days ago                │
-- │ churned      │ 2+ orders AND last order more than 365 days ago          │
-- └──────────────┴──────────────────────────────────────────────────────────┘
--
-- "dataset max" = the most recent order_purchase_timestamp in the dataset.
-- This makes the segmentation reproducible regardless of when the query runs.
--
-- Additional columns:
--   spend_quartile   — 1 (top 25% spenders) to 4 (bottom 25%)
--   value_tier       — human-readable spend tier for reporting
--
-- Grain: one row per customer_unique_id
-- =============================================================================

WITH latest_date AS (
    -- Use dataset max date as reference (reproducible, not NOW())
    SELECT MAX(purchased_at) AS reference_date
    FROM int_orders_enriched
    WHERE order_status != 'canceled'
),

customer_data AS (
    SELECT
        cm.*,
        ld.reference_date,
        ROUND(
            EXTRACT(DAY FROM (ld.reference_date - cm.last_order_at))::numeric
        , 0)                                AS days_since_last_order
    FROM int_customer_metrics cm
    CROSS JOIN latest_date ld
),

segmented AS (
    SELECT
        *,
        CASE
            WHEN total_orders = 1                         THEN 'new'
            WHEN total_orders > 1
             AND days_since_last_order <= 180             THEN 'returning'
            WHEN total_orders > 1
             AND days_since_last_order BETWEEN 181 AND 365 THEN 'at_risk'
            WHEN total_orders > 1
             AND days_since_last_order > 365              THEN 'churned'
            ELSE 'unknown'
        END                                AS customer_segment,

        -- Spend quartile: 1 = highest spend, 4 = lowest spend
        NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
    FROM customer_data
)

SELECT
    customer_unique_id,
    customer_segment,
    total_orders,
    ROUND(total_spend::numeric, 2)         AS total_spend,
    ROUND(avg_order_value::numeric, 2)     AS avg_order_value,
    first_order_at,
    last_order_at,
    days_since_last_order,
    customer_lifetime_days,
    avg_days_between_orders,
    ROUND(avg_review_score::numeric, 2)    AS avg_review_score,
    preferred_state,
    spend_quartile,

    -- Value tier label for business-friendly reporting
    CASE spend_quartile
        WHEN 1 THEN 'high_value'
        WHEN 2 THEN 'mid_value'
        WHEN 3 THEN 'low_value'
        WHEN 4 THEN 'at_risk_value'
    END                                    AS value_tier,

    reference_date                         AS reference_date_used

FROM segmented
ORDER BY total_spend DESC;
