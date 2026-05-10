-- =============================================================================
-- Model  : mart_product_performance
-- Layer  : Mart
-- Sources: stg_products, stg_order_items, int_orders_enriched
--
-- Purpose:
--   Aggregates product-level performance metrics for Senior Manager reporting.
--   Ranks products both globally (revenue_rank) and within their category
--   (category_revenue_rank). Includes quality signals (review score, low-score
--   rate) alongside commercial metrics (revenue, units sold).
--
-- Business value:
--   - Identify best and worst performing products
--   - Surface high-revenue categories with poor customer satisfaction
--   - Support product portfolio decisions (discontinue, promote, investigate)
--
-- Grain: one row per product_id
-- Excludes: cancelled orders, products with no sales
-- =============================================================================

WITH product_sales AS (
    SELECT
        oi.product_id,
        p.category_name_en                                    AS category,

        -- Volume
        COUNT(DISTINCT oi.order_id)                           AS total_orders,
        COUNT(oi.item_sequence)                               AS units_sold,

        -- Revenue
        ROUND(SUM(oi.item_price)::numeric, 2)                 AS total_revenue,
        ROUND(AVG(oi.item_price)::numeric, 2)                 AS avg_unit_price,
        ROUND(SUM(oi.freight_cost)::numeric, 2)               AS total_freight,

        -- Quality signals from reviews
        ROUND(AVG(oe.avg_review_score)::numeric, 2)           AS avg_review_score,
        COUNT(CASE WHEN oe.has_low_score THEN 1 END)          AS low_score_order_count,
        ROUND(
            COUNT(CASE WHEN oe.has_low_score THEN 1 END) * 100.0
            / NULLIF(COUNT(DISTINCT oi.order_id), 0)
        , 1)                                                  AS low_score_rate_pct,

        -- Delivery performance
        COUNT(CASE WHEN oe.is_late_delivery THEN 1 END)       AS late_delivery_count,
        ROUND(
            COUNT(CASE WHEN oe.is_late_delivery THEN 1 END) * 100.0
            / NULLIF(COUNT(DISTINCT oi.order_id), 0)
        , 1)                                                  AS late_delivery_rate_pct

    FROM stg_order_items oi
    JOIN stg_products p           ON p.product_id  = oi.product_id
    JOIN int_orders_enriched oe   ON oe.order_id   = oi.order_id
    WHERE oe.order_status != 'canceled'
    GROUP BY oi.product_id, p.category_name_en
),

category_totals AS (
    -- Pre-compute category revenue for category share calculation
    SELECT
        category,
        SUM(total_revenue) AS category_total_revenue
    FROM product_sales
    GROUP BY category
)

SELECT
    ps.product_id,
    ps.category,
    ps.total_orders,
    ps.units_sold,
    ps.total_revenue,
    ps.avg_unit_price,
    ps.total_freight,
    ps.avg_review_score,
    ps.low_score_order_count,
    ps.low_score_rate_pct,
    ps.late_delivery_count,
    ps.late_delivery_rate_pct,

    -- Revenue share within category (how dominant is this product?)
    ROUND(
        ps.total_revenue * 100.0 / NULLIF(ct.category_total_revenue, 0)
    , 2)                                                        AS category_revenue_share_pct,

    -- Global and category-level rankings
    RANK() OVER (ORDER BY ps.total_revenue DESC)                AS revenue_rank,
    RANK() OVER (
        PARTITION BY ps.category
        ORDER BY ps.total_revenue DESC
    )                                                           AS category_revenue_rank,

    -- Quality-adjusted ranking: penalise high revenue but low satisfaction
    RANK() OVER (
        ORDER BY (ps.avg_review_score * ps.total_revenue) DESC NULLS LAST
    )                                                           AS quality_adjusted_rank

FROM product_sales ps
JOIN category_totals ct ON ct.category = ps.category
ORDER BY revenue_rank;
