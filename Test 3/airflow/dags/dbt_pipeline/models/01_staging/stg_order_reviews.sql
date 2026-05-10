-- =============================================================================
-- Model  : stg_order_reviews
-- Layer  : Staging
-- Source : public.order_reviews
--
-- Purpose:
--   Renames columns, casts score to integer, derives is_low_score boolean
--   flag (score <= 2), strips whitespace from text fields, and converts
--   empty strings to NULL for downstream consistency.
--
-- Business rule:
--   is_low_score = TRUE when review_score <= 2.
--   This threshold represents 1-star and 2-star reviews — strong negative
--   customer signals used for quality monitoring downstream.
--
-- Columns:
--   review_id      — review identifier (not guaranteed unique in source)
--   order_id       — FK to stg_orders
--   score          — review score 1–5
--   is_low_score   — TRUE if score <= 2 (poor experience flag)
--   review_title   — optional short title (NULL if blank)
--   review_message — optional long-form comment (NULL if blank)
--   created_at     — when customer submitted the review
--   answered_at    — when Olist answered the review
-- =============================================================================

SELECT
    review_id,
    order_id,
    review_score::int                               AS score,
    (review_score <= 2)                             AS is_low_score,

    -- Convert blank strings to NULL for consistent NULL handling downstream
    NULLIF(TRIM(review_comment_title),   '')        AS review_title,
    NULLIF(TRIM(review_comment_message), '')        AS review_message,

    review_creation_date                            AS created_at,
    review_answer_timestamp                         AS answered_at

FROM order_reviews
WHERE order_id IS NOT NULL
  AND review_score IS NOT NULL;

