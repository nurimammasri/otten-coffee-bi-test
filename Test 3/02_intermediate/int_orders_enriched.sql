-- =============================================================================
-- Model  : int_orders_enriched
-- Layer  : Intermediate
-- Sources: stg_orders, stg_customers, stg_order_items, stg_order_payments,
--          stg_order_reviews
--
-- Purpose:
--   Produces one enriched row per order by joining all staging models.
--   Calculates delivery performance metrics and payment summaries.
--   This model is the primary fact-like table consumed by mart models.
--
-- Key derived columns:
--   delivery_delay_days — positive = late, negative = early (in calendar days)
--   is_late_delivery    — TRUE when actual delivery exceeded the promised date
--   total_delivery_days — total elapsed days from purchase to delivery
--   total_payment       — sum of all payment records for the order
--   primary_payment_type— payment type with highest payment_amount in the order
--
-- Grain: one row per order_id
-- =============================================================================

WITH order_agg AS (
    -- Aggregate item-level metrics to order level
    SELECT
        order_id,
        ROUND(SUM(item_price)::numeric,  2) AS total_items_price,
        ROUND(SUM(freight_cost)::numeric, 2) AS total_freight,
        COUNT(item_sequence)                 AS item_count
    FROM stg_order_items
    GROUP BY order_id
),

payment_agg AS (
    -- Aggregate payment records to order level
    -- Primary payment type = the type contributing the most value
    SELECT
        order_id,
        ROUND(SUM(payment_amount)::numeric, 2)          AS total_payment,
        MAX(installments)                                AS max_installments,
        (   -- Identify dominant payment type by payment amount
            SELECT payment_type
            FROM stg_order_payments sp2
            WHERE sp2.order_id = sp.order_id
            ORDER BY payment_amount DESC
            LIMIT 1
        )                                                AS primary_payment_type
    FROM stg_order_payments sp
    GROUP BY order_id
),

review_agg AS (
    -- Aggregate reviews to order level (an order can have multiple review rows)
    SELECT
        order_id,
        ROUND(AVG(score)::numeric, 1) AS avg_review_score,
        BOOL_OR(is_low_score)         AS has_low_score,
        COUNT(*)                      AS review_count
    FROM stg_order_reviews
    GROUP BY order_id
)

SELECT
    -- Order identifiers
    o.order_id,
    o.customer_id,
    c.customer_unique_id,

    -- Customer geography
    c.city            AS customer_city,
    c.state           AS customer_state,

    -- Order lifecycle
    o.order_status,
    o.purchased_at,
    o.approved_at,
    o.shipped_at,
    o.delivered_at,
    o.estimated_delivery_at,

    -- Item and freight totals
    COALESCE(oa.total_items_price, 0) AS total_items_price,
    COALESCE(oa.total_freight,     0) AS total_freight,
    COALESCE(oa.item_count,        0) AS item_count,

    -- Payment info
    COALESCE(pa.total_payment,  0)    AS total_payment,
    pa.primary_payment_type,
    COALESCE(pa.max_installments, 1)  AS max_installments,

    -- Review info
    ra.avg_review_score,
    COALESCE(ra.has_low_score, FALSE) AS has_low_score,
    COALESCE(ra.review_count,  0)     AS review_count,

    -- -------------------------------------------------------------------------
    -- Delivery performance metrics
    -- -------------------------------------------------------------------------

    -- Positive = delivered late, negative = delivered early, NULL = not yet delivered
    CASE
        WHEN o.delivered_at IS NOT NULL
         AND o.estimated_delivery_at IS NOT NULL
        THEN ROUND(
            EXTRACT(EPOCH FROM (o.delivered_at - o.estimated_delivery_at))
            / 86400.0
        , 1)
    END                               AS delivery_delay_days,

    -- Boolean flag: TRUE if order arrived after the promised date
    CASE
        WHEN o.delivered_at > o.estimated_delivery_at THEN TRUE
        ELSE FALSE
    END                               AS is_late_delivery,

    -- Total days from purchase to delivery (NULL if not yet delivered)
    CASE
        WHEN o.delivered_at IS NOT NULL AND o.purchased_at IS NOT NULL
        THEN ROUND(
            EXTRACT(EPOCH FROM (o.delivered_at - o.purchased_at))
            / 86400.0
        , 1)
    END                               AS total_delivery_days

FROM stg_orders o
JOIN stg_customers c          ON c.customer_id = o.customer_id
LEFT JOIN order_agg oa        ON oa.order_id   = o.order_id
LEFT JOIN payment_agg pa      ON pa.order_id   = o.order_id
LEFT JOIN review_agg ra       ON ra.order_id   = o.order_id;
