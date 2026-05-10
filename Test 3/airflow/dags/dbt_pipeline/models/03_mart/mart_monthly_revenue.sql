-- =============================================================================
-- Model  : mart_monthly_revenue
-- Layer  : Mart
-- Sources: int_orders_enriched
--
-- Purpose:
--   Monthly aggregation of key business metrics: revenue, order volume,
--   unique customers, average order value, and month-over-month growth rate.
--   Designed for the Senior Manager dashboard — one row per calendar month.
--
-- Business rules:
--   - Excludes 'canceled' and 'unavailable' orders
--   - Revenue = sum of total_payment (actual payment captured, not item price)
--   - MoM growth is relative to the immediately preceding calendar month
--   - Months with zero revenue (e.g., data gaps) show NULL for MoM calculations
--
-- Grain: one row per calendar month
-- Refresh: full refresh recommended (aggregations are non-idempotent with incremental)
-- =============================================================================

WITH monthly_base AS (
    SELECT
        DATE_TRUNC('month', purchased_at)::date          AS month,
        COUNT(DISTINCT order_id)                          AS total_orders,
        COUNT(DISTINCT customer_unique_id)                AS unique_customers,
        ROUND(SUM(total_payment)::numeric,   2)           AS total_revenue,
        ROUND(AVG(total_payment)::numeric,   2)           AS avg_order_value,
        ROUND(SUM(total_items_price)::numeric, 2)         AS total_items_revenue,
        ROUND(SUM(total_freight)::numeric,   2)           AS total_freight_revenue,
        COUNT(CASE WHEN is_late_delivery THEN 1 END)      AS late_delivery_count,
        ROUND(
            COUNT(CASE WHEN is_late_delivery THEN 1 END) * 100.0
            / NULLIF(COUNT(DISTINCT order_id), 0)
        , 1)                                              AS late_delivery_rate_pct,
        ROUND(AVG(avg_review_score)::numeric, 2)          AS avg_review_score
    FROM {{ ref('int_orders_enriched') }}
    WHERE order_status NOT IN ('canceled', 'unavailable')
      AND purchased_at IS NOT NULL
    GROUP BY 1
)
SELECT
    month,
    total_orders,
    unique_customers,
    total_revenue,
    avg_order_value,
    total_items_revenue,
    total_freight_revenue,
    late_delivery_count,
    late_delivery_rate_pct,
    avg_review_score,

    -- Month-over-month comparisons
    LAG(total_revenue) OVER (ORDER BY month)              AS prev_month_revenue,
    LAG(total_orders)  OVER (ORDER BY month)              AS prev_month_orders,

    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY month))
        * 100.0
        / NULLIF(LAG(total_revenue) OVER (ORDER BY month), 0)
    , 2)                                                  AS mom_revenue_growth_pct,

    ROUND(
        (total_orders - LAG(total_orders) OVER (ORDER BY month))
        * 100.0
        / NULLIF(LAG(total_orders) OVER (ORDER BY month), 0)
    , 2)                                                  AS mom_orders_growth_pct,

    -- Running totals (year-to-date context)
    SUM(total_revenue) OVER (
        PARTITION BY EXTRACT(YEAR FROM month)
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                     AS ytd_revenue,

    SUM(total_orders) OVER (
        PARTITION BY EXTRACT(YEAR FROM month)
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                     AS ytd_orders

FROM monthly_base
ORDER BY month
