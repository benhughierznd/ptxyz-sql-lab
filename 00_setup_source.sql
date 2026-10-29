-- =============================================================================
-- Track 3 - SQL & Dimensional Modeling
-- PT XYZ synthetic source data (tobacco / FMCG distribution, Indonesia)
--
-- Run once per participant, in either:
--   - the browser: open https://shell.duckdb.org and paste this whole file, or
--   - the DuckDB CLI: duckdb training_db.duckdb -f 00_setup_source.sql
--
-- Every value is computed from a fixed hash, not random(), so every laptop gets
-- exactly the same rows and the same totals as the slides and answer keys.
-- The data is fictional. Company, brands, outlets and distributors are made up.
-- =============================================================================

-- Data volume. Sized to run inside a browser tab (DuckDB-WASM, about 3 GB of memory).
SET VARIABLE n_outlets   = 50000;
SET VARIABLE n_orders    = 375000;
SET VARIABLE n_lab_lines = 6000000;

CREATE SCHEMA IF NOT EXISTS source;
CREATE SCHEMA IF NOT EXISTS lab;

-- Deterministic pseudo-random number in [0, 1) for a row id and a salt.
CREATE OR REPLACE MACRO mix32(x) AS (xor(x, x >> 16) * 73244475) % 4294967296;
CREATE OR REPLACE MACRO rnd(i, salt) AS
    mix32(mix32(mix32((i * 2654435761 + salt * 97531) % 4294967296))) / 4294967296.0;
CREATE OR REPLACE MACRO rint(i, salt, lo, hi) AS
    CAST(lo + floor(rnd(i, salt) * (hi - lo + 1)) AS INTEGER);

-- -----------------------------------------------------------------------------
-- region: 5 sales regions
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.region AS
SELECT * FROM (VALUES
    (1, 'SUMATERA'),
    (2, 'JAWA BARAT'),
    (3, 'JAWA TENGAH'),
    (4, 'JAWA TIMUR'),
    (5, 'INDONESIA TIMUR')
) t(rg_region_id, rg_name);

-- -----------------------------------------------------------------------------
-- area: 25 sales areas, 5 per region
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.area AS
SELECT * FROM (VALUES
    ( 1, 'MEDAN',       1), ( 2, 'PEKANBARU',   1), ( 3, 'PADANG',      1), ( 4, 'PALEMBANG',   1), ( 5, 'LAMPUNG',     1),
    ( 6, 'JAKARTA',     2), ( 7, 'BOGOR',       2), ( 8, 'BEKASI',      2), ( 9, 'BANDUNG',     2), (10, 'CIREBON',     2),
    (11, 'SEMARANG',    3), (12, 'SOLO',        3), (13, 'YOGYAKARTA',  3), (14, 'TEGAL',       3), (15, 'PURWOKERTO',  3),
    (16, 'SURABAYA',    4), (17, 'MALANG',      4), (18, 'KEDIRI',      4), (19, 'JEMBER',      4), (20, 'DENPASAR',    4),
    (21, 'MAKASSAR',    5), (22, 'BALIKPAPAN',  5), (23, 'BANJARMASIN', 5), (24, 'MANADO',      5), (25, 'KUPANG',      5)
) t(ar_area_id, ar_name, ar_region_id);

-- -----------------------------------------------------------------------------
-- outlet: 50,000 retail outlets that order from PT XYZ distributors
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.outlet AS
SELECT
    i                                              AS ot_outlet_id,
    'Outlet#' || lpad(CAST(i AS VARCHAR), 6, '0')  AS ot_name,
    CASE
        WHEN rnd(i, 1) < 0.55 THEN 'GENERAL TRADE'
        WHEN rnd(i, 1) < 0.70 THEN 'GROSIR'
        WHEN rnd(i, 1) < 0.85 THEN 'MODERN TRADE'
        WHEN rnd(i, 1) < 0.93 THEN 'HORECA'
        ELSE 'KOPERASI'
    END                                            AS ot_channel,
    rint(i, 2, 1, 25)                              AS ot_area_id,
    DATE '2010-01-01' + rint(i, 3, 0, 3000)        AS ot_open_date
FROM range(1, getvariable('n_outlets') + 1) r(i);

-- -----------------------------------------------------------------------------
-- distributor: 1,000 distributors, 40 per area
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.distributor AS
SELECT
    i                                                   AS dt_distributor_id,
    'Distributor#' || lpad(CAST(i AS VARCHAR), 4, '0')  AS dt_name,
    CAST((i - 1) % 25 + 1 AS INTEGER)                   AS dt_area_id
FROM range(1, 1001) r(i);

-- -----------------------------------------------------------------------------
-- sku: 2,000 SKUs across 20 brands and 3 segments
--   SKT = sigaret kretek tangan, SKM = sigaret kretek mesin, SPM = sigaret putih mesin
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.sku AS
WITH base AS (
    SELECT
        i,
        'BRAND ' || chr(CAST(65 + (i - 1) % 20 AS INTEGER))                 AS brand,
        CASE WHEN (i - 1) % 20 < 7 THEN 'SKM'
             WHEN (i - 1) % 20 < 14 THEN 'SKT'
             ELSE 'SPM' END                                                  AS segment,
        ['REGULAR', 'MILD', 'FILTER', 'BOLD', 'MENTHOL'][rint(i, 11, 1, 5)]  AS variant
    FROM range(1, 2001) r(i)
)
SELECT
    i                                                                  AS sk_sku_id,
    brand || ' ' || variant || ' ' ||
        CASE segment WHEN 'SKT' THEN 12 WHEN 'SKM' THEN 16 ELSE 20 END ||
        ' #' || lpad(CAST(i AS VARCHAR), 4, '0')                       AS sk_name,
    brand                                                              AS sk_brand,
    segment                                                            AS sk_segment,
    variant                                                            AS sk_variant,
    CASE segment WHEN 'SKT' THEN 12 WHEN 'SKM' THEN 16 ELSE 20 END     AS sk_sticks_per_pack,
    -- price per pack in IDR, rounded to 500
    CAST(CASE segment WHEN 'SKT' THEN 20000 WHEN 'SKM' THEN 28000 ELSE 35000 END
         + rint(i, 12, 0, 20) * 500 AS DECIMAL(12, 2))                 AS sk_price_per_pack
FROM base;

-- -----------------------------------------------------------------------------
-- distributor_stock: each SKU is held by 4 distributors (8,000 rows)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.distributor_stock AS
SELECT
    s.sk_sku_id                                               AS st_sku_id,
    CAST((s.sk_sku_id - 1 + j * 250) % 1000 + 1 AS INTEGER)   AS st_distributor_id,
    rint(s.sk_sku_id * 4 + j, 21, 100, 9999)                  AS st_stock_slof,
    CAST(s.sk_price_per_pack * 10 * (0.60 + rint(s.sk_sku_id * 4 + j, 22, 0, 20) / 100.0)
         AS DECIMAL(14, 2))                                   AS st_unit_cost_slof
FROM source.sku s, range(0, 4) r(j);

-- -----------------------------------------------------------------------------
-- distributor_stock_daily: the stock of every SKU at every distributor at the end
-- of each day, for the 365 days up to 2 August 2025 (2,920,000 rows)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.distributor_stock_daily AS
SELECT
    DATE '2025-08-02' - d::INTEGER                                     AS sd_snapshot_date,
    st.st_sku_id                                                       AS sd_sku_id,
    st.st_distributor_id                                               AS sd_distributor_id,
    -- today's stock, moved up or down by up to 20% on each day
    CAST(st.st_stock_slof
         * (80 + rint(st.st_sku_id * 4000 + st.st_distributor_id * 400 + d, 23, 0, 40))
         / 100 AS INTEGER)                                             AS sd_stock_slof
FROM source.distributor_stock st, range(0, 365) r(d);

-- -----------------------------------------------------------------------------
-- sales_order_line: 1 to 7 lines per order (about 4 on average)
-- Orders run from 1 January 2019 to 2 August 2025, so 2025 is a partial year.
-- Quantities are in slof (1 slof = 10 packs).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.sales_order_line AS
WITH orders AS (
    SELECT
        i                                          AS order_id,
        rint(i, 31, 1, 7)                          AS line_count,
        DATE '2019-01-01' + rint(i, 32, 0, 2405)   AS order_date
    FROM range(1, getvariable('n_orders') + 1) r(i)
),
lines AS (
    SELECT
        o.order_id,
        CAST(n AS INTEGER)                          AS line_no,
        o.order_date,
        o.order_id * 8 + n                          AS k,
        rint(o.order_id * 8 + n, 41, 1, 2000)       AS sku_id
    FROM orders o, range(1, 8) r(n)
    WHERE n <= o.line_count
)
SELECT
    l.order_id                                                         AS sl_order_id,
    l.line_no                                                          AS sl_line_no,
    l.sku_id                                                           AS sl_sku_id,
    CAST((l.sku_id - 1 + rint(l.k, 42, 0, 3) * 250) % 1000 + 1 AS INTEGER) AS sl_distributor_id,
    rint(l.k, 43, 1, 50)                                               AS sl_qty_slof,
    CAST(rint(l.k, 43, 1, 50) * 10 * s.sk_price_per_pack AS DECIMAL(16, 2)) AS sl_gross_amount,
    CAST(rint(l.k, 44, 0, 10) / 100.0 AS DECIMAL(4, 2))                AS sl_discount,
    -- excise (cukai) per stick: illustrative rates by segment
    CAST(rint(l.k, 43, 1, 50) * 10 * s.sk_sticks_per_pack *
         CASE s.sk_segment WHEN 'SKT' THEN 483 WHEN 'SKM' THEN 1231 ELSE 1336 END
         AS DECIMAL(16, 2))                                            AS sl_excise_amount,
    CAST(0.099 AS DECIMAL(4, 3))                                       AS sl_vat_rate,
    l.order_date + rint(l.k, 45, 1, 4)                                 AS sl_ship_date,
    l.order_date + rint(l.k, 46, 2, 5)                                 AS sl_promised_date,
    l.order_date + rint(l.k, 45, 1, 4) + rint(l.k, 47, 0, 3)           AS sl_delivery_date
FROM lines l
JOIN source.sku s ON l.sku_id = s.sk_sku_id
-- the operational system stores lines by order, not by date
ORDER BY l.order_id, l.line_no;

-- -----------------------------------------------------------------------------
-- sales_order: order header, with the total the ordering system calculated
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE source.sales_order AS
WITH totals AS (
    SELECT sl_order_id,
           SUM(sl_gross_amount * (1 - sl_discount) * (1 + sl_vat_rate)) AS total_amount
    FROM source.sales_order_line
    GROUP BY sl_order_id
)
SELECT
    i                                                           AS so_order_id,
    rint(i, 33, 1, getvariable('n_outlets'))                                      AS so_outlet_id,
    DATE '2019-01-01' + rint(i, 32, 0, 2405)                    AS so_order_date,
    CASE WHEN DATE '2019-01-01' + rint(i, 32, 0, 2405) < DATE '2025-07-25'
         THEN 'DELIVERED' ELSE 'OPEN' END                       AS so_status,
    ['SALESMAN APP', 'TELESALES', 'B2B PORTAL', 'EDI', 'WALK-IN'][rint(i, 34, 1, 5)] AS so_order_source,
    CAST(t.total_amount AS DECIMAL(18, 2))                      AS so_total_amount
FROM range(1, getvariable('n_orders') + 1) r(i)
JOIN totals t ON t.sl_order_id = i
ORDER BY i;

-- -----------------------------------------------------------------------------
-- Lab 7 tables: 6 million sales lines, same data, two load orders.
-- Built here once so nobody waits for the sort during the lab.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE lab.sales_line_by_sku AS
SELECT
    i                                                   AS sl_line_id,
    rint(i, 51, 1, 2000)                                AS sl_sku_id,
    rint(i, 52, 1, 1000)                                AS sl_distributor_id,
    DATE '2019-01-01' + rint(i, 53, 0, 2405)            AS sl_ship_date,
    rint(i, 54, 1, 50)                                  AS sl_qty_slof,
    CAST(rint(i, 54, 1, 50) * 10 * (20000 + rint(i, 55, 0, 40) * 500) AS DECIMAL(16, 2)) AS sl_gross_amount,
    CAST(rint(i, 56, 0, 10) / 100.0 AS DECIMAL(4, 2))   AS sl_discount
FROM range(1, getvariable('n_lab_lines') + 1) r(i)
ORDER BY sl_sku_id;

CREATE OR REPLACE TABLE lab.sales_line_by_date AS
SELECT * FROM lab.sales_line_by_sku ORDER BY sl_ship_date;

CHECKPOINT;

-- The random-number helpers are only for this build: drop them so the Schema panel shows
-- the participants' own macros only.
DROP MACRO rint;
DROP MACRO rnd;
DROP MACRO mix32;

-- Quick check: compare with the scenario table in the Study Case.
SELECT 'sales_order_line' AS table_name, COUNT(*) AS row_count FROM source.sales_order_line
UNION ALL SELECT 'sales_order',       COUNT(*) FROM source.sales_order
UNION ALL SELECT 'outlet',            COUNT(*) FROM source.outlet
UNION ALL SELECT 'sku',               COUNT(*) FROM source.sku
UNION ALL SELECT 'distributor',       COUNT(*) FROM source.distributor
UNION ALL SELECT 'distributor_stock', COUNT(*) FROM source.distributor_stock
UNION ALL SELECT 'distributor_stock_daily', COUNT(*) FROM source.distributor_stock_daily
UNION ALL SELECT 'area',              COUNT(*) FROM source.area
UNION ALL SELECT 'region',            COUNT(*) FROM source.region;
