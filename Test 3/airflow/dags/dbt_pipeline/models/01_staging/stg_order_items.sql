-- =============================================================================
-- Model  : stg_order_items
-- Layer  : Staging
-- Source : public.order_items
--
-- Purpose:
--   Standardises column names, casts numeric fields to fixed-precision NUMERIC,
--   and derives a convenient total_item_cost column (price + freight).
--   No business logic — clean rename and cast only.
--
-- Columns:
--   order_id          — FK to stg_orders
--   item_sequence     — line number within an order (1-based)
--   product_id        — FK to stg_products
--   seller_id         — FK to sellers
--   shipping_deadline — latest date seller must hand to carrier
--   item_price        — price of a single item
--   freight_cost      — shipping cost for this item
--   total_item_cost   — derived: item_price + freight_cost
-- =============================================================================

SELECT
    order_id,
    order_item_id                           AS item_sequence,
    product_id,
    seller_id,
    shipping_limit_date                     AS shipping_deadline,
    ROUND(price::numeric, 2)                AS item_price,
    ROUND(freight_value::numeric, 2)        AS freight_cost,
    ROUND((price + freight_value)::numeric, 2) AS total_item_cost

FROM order_items
WHERE order_id     IS NOT NULL
  AND product_id   IS NOT NULL
  AND price        IS NOT NULL
