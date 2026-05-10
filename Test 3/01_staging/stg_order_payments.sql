-- =============================================================================
-- Model  : stg_order_payments
-- Layer  : Staging
-- Source : public.order_payments
--
-- Purpose:
--   Renames columns, casts payment_value to NUMERIC precision, ensures
--   payment_sequential (used as tie-breaker) is integer. One order can
--   have multiple payment rows (split payments, installments).
--
-- Note: This model keeps one row per payment record. Aggregation to order-level
--       happens in the intermediate layer (int_orders_enriched).
--
-- Columns:
--   order_id        — FK to stg_orders
--   payment_seq     — sequential number of this payment within the order
--   payment_type    — credit_card | boleto | voucher | debit_card | not_defined
--   installments    — number of installments chosen (1 = single payment)
--   payment_amount  — value of this specific payment record
-- =============================================================================

SELECT
    order_id,
    payment_sequential              AS payment_seq,
    payment_type,
    payment_installments            AS installments,
    ROUND(payment_value::numeric, 2) AS payment_amount

FROM order_payments
WHERE order_id IS NOT NULL
  AND payment_value IS NOT NULL
  AND payment_value >= 0;
