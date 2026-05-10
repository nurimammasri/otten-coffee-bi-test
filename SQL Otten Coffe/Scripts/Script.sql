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