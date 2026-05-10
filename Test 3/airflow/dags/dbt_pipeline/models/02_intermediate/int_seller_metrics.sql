-- =============================================================================
-- Model  : int_seller_metrics
-- Layer  : Intermediate
-- Sources: stg_order_items, int_orders_enriched
--
-- Purpose:
--   Aggregates performance metrics per seller. Provides a seller-level summary
--   used in dashboards to identify top and bottom performers.
--
-- Business metrics computed:
--   - Revenue, order count, items sold
--   - Average review score and low-score rate (customer satisfaction signal)
--   - Late delivery count and rate (operational reliability signal)
--   - Average days late (severity of lateness)
--   - Top category by revenue (seller's primary business focus)
--
-- Grain: one row per seller_id
-- Only includes non-cancelled orders (status != 'canceled')
-- =============================================================================

WITH seller_base AS (
    -- Join items to enriched orders to get per-item order context
    SELECT
        oi.seller_id,
        oi.order_id,
        oi.item_price,
        oe.order_status,
        oe.avg_review_score,
        oe.is_late_delivery,
        oe.delivery_delay_days,
        oe.has_low_score
    FROM {{ ref('stg_order_items') }} oi
    JOIN {{ ref('int_orders_enriched') }} oe ON oe.order_id = oi.order_id
    WHERE oe.order_status != 'canceled'
),

seller_top_category AS (
    -- Identify the top-revenue category per seller
    SELECT DISTINCT ON (oi.seller_id)
        oi.seller_id,
        p.category_name_en                      AS top_category,
        SUM(oi.item_price) OVER (
            PARTITION BY oi.seller_id, p.category_name_en
        )                                       AS category_revenue
    FROM {{ ref('stg_order_items') }} oi
    JOIN {{ ref('stg_products') }} p ON p.product_id = oi.product_id
    JOIN {{ ref('int_orders_enriched') }} oe ON oe.order_id = oi.order_id
    WHERE oe.order_status != 'canceled'
    ORDER BY oi.seller_id, category_revenue DESC
)

SELECT
    sb.seller_id,

    -- Volume metrics
    COUNT(DISTINCT sb.order_id)                                  AS total_orders,
    COUNT(*)                                                     AS total_items_sold,
    ROUND(SUM(sb.item_price)::numeric, 2)                        AS total_revenue,
    ROUND(AVG(sb.item_price)::numeric, 2)                        AS avg_item_price,
    ROUND(
        SUM(sb.item_price)::numeric / NULLIF(COUNT(DISTINCT sb.order_id), 0)
    , 2)                                                         AS avg_revenue_per_order,

    -- Customer satisfaction metrics
    ROUND(AVG(sb.avg_review_score)::numeric, 2)                  AS avg_review_score,
    COUNT(CASE WHEN sb.has_low_score THEN 1 END)                 AS low_score_orders,
    ROUND(
        COUNT(CASE WHEN sb.has_low_score THEN 1 END) * 100.0
        / NULLIF(COUNT(DISTINCT sb.order_id), 0)
    , 1)                                                         AS low_score_rate_pct,

    -- Delivery performance metrics
    COUNT(CASE WHEN sb.is_late_delivery THEN 1 END)              AS late_delivery_count,
    ROUND(
        COUNT(CASE WHEN sb.is_late_delivery THEN 1 END) * 100.0
        / NULLIF(COUNT(DISTINCT sb.order_id), 0)
    , 1)                                                         AS late_delivery_rate_pct,
    ROUND(
        AVG(CASE WHEN sb.is_late_delivery THEN sb.delivery_delay_days END)::numeric
    , 1)                                                         AS avg_days_late,

    -- Top category
    stc.top_category

FROM seller_base sb
LEFT JOIN seller_top_category stc ON stc.seller_id = sb.seller_id
GROUP BY sb.seller_id, stc.top_category
ORDER BY total_revenue DESC
