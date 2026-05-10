-- =============================================================================
-- Model  : int_customer_metrics
-- Layer  : Intermediate
-- Sources: int_orders_enriched
--
-- Purpose:
--   Aggregates lifetime metrics per unique customer (using customer_unique_id).
--   Powers customer segmentation in mart_customer_segments and customer-level
--   analytics in dashboards.
--
-- Key derived fields:
--   customer_lifetime_days — span from first to last order (0 for one-time buyers)
--   avg_days_between_orders— purchase frequency indicator
--   preferred_state        — state from which customer most frequently orders
--
-- Grain: one row per customer_unique_id
-- Excludes cancelled orders from spend and order counts
-- =============================================================================

WITH customer_base AS (
    SELECT
        customer_unique_id,
        order_id,
        purchased_at,
        total_payment,
        avg_review_score,
        order_status,
        customer_state
    FROM int_orders_enriched
    WHERE order_status != 'canceled'
      AND purchased_at IS NOT NULL
),

customer_state_mode AS (
    -- Determine the state the customer orders from most often
    SELECT DISTINCT ON (customer_unique_id)
        customer_unique_id,
        customer_state           AS preferred_state,
        COUNT(*) OVER (PARTITION BY customer_unique_id, customer_state) AS state_orders
    FROM customer_base
    ORDER BY customer_unique_id, state_orders DESC
)

SELECT
    cb.customer_unique_id,

    -- Order behaviour
    COUNT(DISTINCT cb.order_id)                           AS total_orders,
    ROUND(SUM(cb.total_payment)::numeric, 2)              AS total_spend,
    ROUND(AVG(cb.total_payment)::numeric, 2)              AS avg_order_value,

    -- Temporal profile
    MIN(cb.purchased_at)                                  AS first_order_at,
    MAX(cb.purchased_at)                                  AS last_order_at,
    ROUND(
        EXTRACT(DAY FROM (MAX(cb.purchased_at) - MIN(cb.purchased_at)))::numeric
    , 0)                                                  AS customer_lifetime_days,

    -- Purchase frequency (NULL for single-purchase customers)
    CASE
        WHEN COUNT(DISTINCT cb.order_id) > 1
        THEN ROUND(
            EXTRACT(DAY FROM (MAX(cb.purchased_at) - MIN(cb.purchased_at)))
            / (COUNT(DISTINCT cb.order_id) - 1.0)
        , 0)
    END                                                   AS avg_days_between_orders,

    -- Satisfaction
    ROUND(AVG(cb.avg_review_score)::numeric, 2)           AS avg_review_score,

    -- Geography
    csm.preferred_state

FROM customer_base cb
LEFT JOIN customer_state_mode csm
    ON csm.customer_unique_id = cb.customer_unique_id
GROUP BY cb.customer_unique_id, csm.preferred_state
ORDER BY total_spend DESC;
