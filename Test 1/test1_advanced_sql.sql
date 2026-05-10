-- =============================================================================
-- Otten Coffee — BI Engineer Technical Test
-- Test 1: Advanced SQL & Data Exploration
-- Dataset: Brazilian E-Commerce (Olist) — Public PostgreSQL on Supabase
--
-- Database:
--   Host    : aws-1-ap-northeast-1.pooler.supabase.com
--   Port    : 5432
--   DB      : postgres
--   User    : public_readonly.hkmqxnppvspaoldrzzam
--
-- Key tables used:
--   orders, order_items, order_payments, order_reviews,
--   customers, products, sellers, product_category_name_translation
-- =============================================================================


-- =============================================================================
-- PART A — CORE SQL QUERIES
-- =============================================================================


-- -----------------------------------------------------------------------------
-- A1: Monthly Revenue Trend
--
-- Calculates total revenue (sum of payment_value) per month, ordered
-- chronologically. Includes month-over-month percentage change.
--
-- Columns: year, month, total_revenue, prev_month_revenue, mom_change_pct
--
-- Assumptions:
--   - Revenue is taken from order_payments.payment_value (actual payments made)
--   - Cancelled orders are excluded from revenue calculation
--   - MoM change for the first month is NULL (no previous period to compare)
-- -----------------------------------------------------------------------------

WITH monthly_revenue AS (
    SELECT
        EXTRACT(YEAR  FROM o.order_purchase_timestamp)::int AS year,
        EXTRACT(MONTH FROM o.order_purchase_timestamp)::int AS month,
        ROUND(SUM(op.payment_value)::numeric, 2)             AS total_revenue
    FROM orders o
    JOIN order_payments op ON op.order_id = o.order_id
    WHERE o.order_status != 'canceled'
      AND o.order_purchase_timestamp IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    year,
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY year, month)          AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY year, month))
        * 100.0
        / NULLIF(LAG(total_revenue) OVER (ORDER BY year, month), 0)
    , 2)                                                    AS mom_change_pct
FROM monthly_revenue
ORDER BY year, month;


-- -----------------------------------------------------------------------------
-- A2: Top 10 Product Categories by Revenue
--
-- Identifies the top 10 product categories (in English) ranked by total revenue.
-- Includes: number of distinct orders, total items sold, average order value.
-- Cancelled orders are excluded.
--
-- Columns: category, distinct_orders, total_items_sold, total_revenue, avg_order_value
--
-- Assumptions:
--   - Revenue uses order_payments.payment_value (captures discounts/installments)
--   - avg_order_value = total_revenue / number of distinct orders per category
--   - Products with no English translation are excluded (INNER JOIN to translation)
--   - 'Cancelled' status filtered out; other statuses (processing, shipped, etc.) included
-- -----------------------------------------------------------------------------

SELECT
    t.product_category_name_english                          AS category,
    COUNT(DISTINCT o.order_id)                               AS distinct_orders,
    COUNT(oi.order_item_id)                                  AS total_items_sold,
    ROUND(SUM(op.payment_value)::numeric, 2)                 AS total_revenue,
    ROUND(
        SUM(op.payment_value)::numeric
        / NULLIF(COUNT(DISTINCT o.order_id), 0)
    , 2)                                                     AS avg_order_value
FROM products p
JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name
JOIN order_items oi    ON oi.product_id = p.product_id
JOIN orders o          ON o.order_id    = oi.order_id
JOIN order_payments op ON op.order_id   = o.order_id
WHERE o.order_status != 'canceled'
GROUP BY t.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- A3: Customer Cohort Retention
--
-- Groups customers by their first purchase month (acquisition cohort).
-- For each cohort, counts how many customers returned in M+1, M+2, M+3.
--
-- Columns: cohort_month, cohort_size, retained_m1, retained_m2, retained_m3
--
-- Assumptions:
--   - Customer identity tracked via customer_unique_id (persists across orders)
--   - "First purchase month" = earliest order_purchase_timestamp per unique customer
--   - Retention = at least one additional order in the target month (not cumulative)
--   - Month offset calculated with integer arithmetic (YEAR*12 + MONTH) to avoid
--     floating-point edge cases with interval arithmetic
--   - Cancelled orders excluded from both cohort assignment and retention counting
-- -----------------------------------------------------------------------------

WITH customer_orders AS (
    -- Deduplicate to one row per (customer, month) to avoid over-counting
    SELECT DISTINCT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status != 'canceled'
      AND o.order_purchase_timestamp IS NOT NULL
),
cohorts AS (
    -- Identify each customer's acquisition cohort (first purchase month)
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
),
month_diff AS (
    -- Calculate exact integer month offset between each activity and the cohort month
    -- Using YEAR*12+MONTH arithmetic avoids issues with variable-length months
    SELECT
        co.customer_unique_id,
        c.cohort_month,
        ( EXTRACT(YEAR  FROM co.order_month)::int * 12
        + EXTRACT(MONTH FROM co.order_month)::int )
        - ( EXTRACT(YEAR  FROM c.cohort_month)::int * 12
          + EXTRACT(MONTH FROM c.cohort_month)::int ) AS months_after_cohort
    FROM customer_orders co
    JOIN cohorts c ON c.customer_unique_id = co.customer_unique_id
    WHERE co.order_month > c.cohort_month   -- only post-cohort activity
)
SELECT
    c.cohort_month,
    COUNT(DISTINCT c.customer_unique_id)                                                 AS cohort_size,
    COUNT(DISTINCT CASE WHEN md.months_after_cohort = 1 THEN md.customer_unique_id END) AS retained_m1,
    COUNT(DISTINCT CASE WHEN md.months_after_cohort = 2 THEN md.customer_unique_id END) AS retained_m2,
    COUNT(DISTINCT CASE WHEN md.months_after_cohort = 3 THEN md.customer_unique_id END) AS retained_m3
FROM cohorts c
LEFT JOIN month_diff md ON md.customer_unique_id = c.customer_unique_id
GROUP BY c.cohort_month
ORDER BY c.cohort_month;


-- =============================================================================
-- PART B — QUERY OPTIMISATION
-- =============================================================================
--
-- ORIGINAL BOTTLENECKS IDENTIFIED:
--
-- 1. TRIPLE TABLE SCAN: The original query scans products and order_items three
--    separate times in three independent subqueries (b, ps, ls). Each subquery
--    re-joins the same large tables from scratch, tripling I/O cost.
--
-- 2. REPEATED WINDOW AGGREGATION: SUM(total_revenue) OVER () appears twice in
--    the outer SELECT for revenue_share_pct and cumulative_revenue_pct. The
--    database must compute a full-table window scan twice instead of once.
--
-- 3. DEEPLY NESTED SUBQUERIES: Three levels of nesting (innermost select → b →
--    outer → final ORDER BY) make it harder for the query planner to choose
--    optimal join order and push down filters.
--
-- 4. REDUNDANT RANK() PLACEMENT: RANK() is computed inside the subquery, then
--    more window functions are layered on top in the outer query, causing extra
--    sorting passes over the result set.
--
-- 5. COUNT(DISTINCT order_id) RECOMPUTED: late_rate_pct divides late_count by
--    COUNT(DISTINCT b.order_id) which was already computed as total_orders —
--    same expression evaluated twice.
--
-- OPTIMISATION STRATEGY:
--
-- - Consolidate all three subqueries (b, ps, ls) into ONE CTE (category_stats)
--   with a single join pass across all tables using FILTER aggregation.
-- - Pre-compute the grand total revenue in a separate scalar CTE (total) and
--   reference it with CROSS JOIN — eliminates both repeated OVER() calls.
-- - Flatten nesting: CTE → single outer SELECT with window functions.
-- - Move all RANK() and window functions to the final SELECT only.
-- - Reuse computed columns (total_orders, total_revenue) instead of re-computing.
--
-- INDEX RECOMMENDATIONS (for a writable environment):
--   CREATE INDEX idx_order_items_product_id ON order_items(product_id);
--   CREATE INDEX idx_order_payments_order_id_type ON order_payments(order_id, payment_type);
--   CREATE INDEX idx_orders_delivered ON orders(order_delivered_customer_date, order_estimated_delivery_date);
--   CREATE INDEX idx_products_category ON products(product_category_name);
--
-- VERIFICATION IN A REAL ENVIRONMENT:
--   EXPLAIN (ANALYZE, BUFFERS) <query>;
--   Compare: "Seq Scan" → "Index Scan", "cost=" values, "actual time=" values.
--   Run both queries 3x and average execution time to account for cache warm-up.
-- -----------------------------------------------------------------------------

WITH category_stats AS (
    -- Single join pass: aggregates all required metrics per category at once.
    -- FILTER clause replaces separate payment-type subqueries without extra scans.
    SELECT
        COALESCE(t.product_category_name_english, 'uncategorized') AS category,
        COUNT(DISTINCT oi.order_id)                                AS total_orders,
        SUM(oi.price)                                              AS total_revenue,
        SUM(op.payment_value)
            FILTER (WHERE op.payment_type = 'credit_card')         AS credit_card_revenue,
        SUM(op.payment_value)
            FILTER (WHERE op.payment_type = 'boleto')              AS boleto_revenue,
        COUNT(DISTINCT CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN o.order_id END)                                   AS late_count,
        ROUND(AVG(CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN EXTRACT(EPOCH FROM
                    (o.order_delivered_customer_date - o.order_estimated_delivery_date)
                ) / 86400.0
            END)::numeric, 1)                                      AS avg_days_late
    FROM products p
    LEFT JOIN product_category_name_translation t
        ON t.product_category_name = p.product_category_name
    JOIN order_items oi    ON oi.product_id  = p.product_id
    JOIN orders o          ON o.order_id     = oi.order_id
    JOIN order_payments op ON op.order_id    = oi.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
    GROUP BY COALESCE(t.product_category_name_english, 'uncategorized')
),
total AS (
    -- Pre-compute grand total once; shared via CROSS JOIN — avoids repeated OVER()
    SELECT SUM(total_revenue) AS grand_total
    FROM category_stats
)
SELECT
    RANK() OVER (ORDER BY cs.total_revenue DESC)                                         AS revenue_rank,
    cs.category,
    cs.total_orders,
    ROUND(cs.total_revenue::numeric, 2)                                                  AS total_revenue,
    ROUND((cs.total_revenue * 100.0 / NULLIF(t.grand_total, 0))::numeric, 2)            AS revenue_share_pct,
    ROUND((
        SUM(cs.total_revenue) OVER (
            ORDER BY cs.total_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 / NULLIF(t.grand_total, 0)
    )::numeric, 2)                                                                       AS cumulative_revenue_pct,
    ROUND((cs.total_revenue / NULLIF(cs.total_orders, 0))::numeric, 2)                  AS avg_order_value,
    ROUND(cs.credit_card_revenue::numeric, 2)                                            AS credit_card_revenue,
    ROUND(cs.boleto_revenue::numeric, 2)                                                 AS boleto_revenue,
    ROUND((cs.credit_card_revenue * 100.0
        / NULLIF(cs.credit_card_revenue + cs.boleto_revenue, 0))::numeric, 1)           AS credit_card_share_pct,
    cs.late_count,
    ROUND((cs.late_count * 100.0 / NULLIF(cs.total_orders, 0))::numeric, 1)             AS late_rate_pct,
    cs.avg_days_late,
    RANK() OVER (
        ORDER BY ROUND((cs.late_count * 100.0 / NULLIF(cs.total_orders, 0))::numeric, 1) DESC
    )                                                                                    AS late_rank
FROM category_stats cs
CROSS JOIN total t
ORDER BY revenue_rank;
