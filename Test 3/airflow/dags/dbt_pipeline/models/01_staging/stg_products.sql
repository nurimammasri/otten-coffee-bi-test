-- =============================================================================
-- Model  : stg_products
-- Layer  : Staging
-- Source : public.products + public.product_category_name_translation
--
-- Purpose:
--   Joins with the translation table to produce English category names alongside
--   the original Portuguese. Renames typo'd source columns (product_name_lenght)
--   to correct spelling. Casts numeric dimension fields.
--
-- Note: LEFT JOIN to translation preserves products with untranslated categories
--       (falls back to 'uncategorized').
--
-- Columns:
--   product_id          — primary key
--   category_name_en    — English category name (from translation table)
--   category_name_pt    — Original Portuguese category name
--   product_name_length — character length of product name
--   description_length  — character length of product description
--   photos_count        — number of product photos
--   weight_grams        — product weight in grams
--   length_cm, height_cm, width_cm — product dimensions
-- =============================================================================

SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, 'uncategorized') AS category_name_en,
    p.product_category_name                                    AS category_name_pt,

    -- Fix source typos in column names (lenght → length)
    p.product_name_lenght                                      AS product_name_length,
    p.product_description_lenght                               AS description_length,
    p.product_photos_qty                                       AS photos_count,

    -- Cast dimensions to numeric for downstream arithmetic
    ROUND(p.product_weight_g::numeric, 0)                      AS weight_grams,
    ROUND(p.product_length_cm::numeric, 1)                     AS length_cm,
    ROUND(p.product_height_cm::numeric, 1)                     AS height_cm,
    ROUND(p.product_width_cm::numeric, 1)                      AS width_cm

FROM products p
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name
WHERE p.product_id IS NOT NULL;

