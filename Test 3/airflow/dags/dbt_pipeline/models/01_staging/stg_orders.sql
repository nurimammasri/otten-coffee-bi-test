-- =============================================================================
-- Model  : stg_orders
-- Layer  : Staging
-- Source : public.orders
--
-- Purpose:
--   Renames columns to consistent snake_case, casts data types explicitly,
--   filters out records with missing primary key. No business logic here —
--   this layer is a clean mirror of the source with standardised shape.
--
-- Columns:
--   order_id               — primary key
--   customer_id            — FK to stg_customers
--   order_status           — raw status from source
--   purchased_at           — when customer placed the order
--   approved_at            — when payment was approved
--   shipped_at             — when carrier picked up the package
--   delivered_at           — when customer received the package
--   estimated_delivery_at  — original delivery promise date
-- =============================================================================

SELECT
    order_id,
    customer_id,
    order_status,

    -- Rename and keep as timestamp (already correct type in source)
    order_purchase_timestamp       AS purchased_at,
    order_approved_at              AS approved_at,
    order_delivered_carrier_date   AS shipped_at,
    order_delivered_customer_date  AS delivered_at,
    order_estimated_delivery_date  AS estimated_delivery_at

FROM orders
WHERE order_id IS NOT NULL
