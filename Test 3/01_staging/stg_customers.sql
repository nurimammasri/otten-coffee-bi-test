-- =============================================================================
-- Model  : stg_customers
-- Layer  : Staging
-- Source : public.customers
--
-- Purpose:
--   Renames columns, normalises city/state casing for consistent downstream
--   joins and display. No business logic.
--
-- Note on customer identity:
--   customer_id     — unique per order (one customer can have many customer_ids)
--   customer_unique_id — true customer identity across orders (use this for
--                        customer-level analysis and cohort tracking)
--
-- Columns:
--   customer_id         — order-level customer identifier (FK in orders)
--   customer_unique_id  — persistent customer identity across orders
--   zip_code            — 5-digit zip code prefix
--   city                — title-cased city name
--   state               — 2-char upper-case state abbreviation (BR)
-- =============================================================================

SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix              AS zip_code,
    INITCAP(LOWER(customer_city))         AS city,
    UPPER(customer_state)                 AS state

FROM customers
WHERE customer_id IS NOT NULL;
