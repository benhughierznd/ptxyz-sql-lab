# Sampoerna SQL Lab

A browser-based SQL lab for a two-day training on SQL and dimensional modeling.
It runs [DuckDB](https://duckdb.org) inside the browser tab with DuckDB-WASM: nothing to install, no login, no server, and no data leaves the laptop.

Open it: **https://benhughierznd.github.io/ptxyz-sql-lab/**

## For participants

1. Open the page in a recent Chrome or Edge and wait until the top right says **Ready**.
2. Click **Build PT XYZ data**. It creates the training data and every Day 1 table in about 30 seconds.
3. Paste SQL into the editor and press **Ctrl+Enter**.
   Select part of the text to run only the selection.
4. Under the editor, every statement gets one line: seconds, rows scanned, row groups scanned, rows returned.
   Seconds and rows scanned come from the DuckDB profiler (the same numbers `EXPLAIN ANALYZE` shows).
5. When the last query joins tables, the result gets an **ERD** tab next to **Table**.
   It draws the tables of that query with their primary and foreign keys, and each join with its type and its 1 or many ends.
   Click a table in the diagram to read what it is.
6. The **Schema** panel lists every schema, table and view, with columns, data types, row count and an estimated uncompressed size.
   Open a table to see its description and its PK and FK columns.
   You can create your own tables too, for example in the `sandbox` schema.

The tables live in the browser tab.
If you close the tab, open the page again and click **Build PT XYZ data**: it builds the source data and every table of Day 1.
The editor text is kept.

To keep your own work, use **Save point**.
It saves every table and view outside `source` and `lab` (keys and comments included) in this browser's private storage, and **Restore** brings them back after the tab or the browser was closed.
Save points belong to one browser on one laptop: use the download button to keep a `.ptxyz` copy, and **Upload a save point** to restore it on another laptop or browser.
Clearing the browser's site data deletes the save points stored in it, not the downloaded files.

## The data

PT XYZ is a fictional cigarette manufacturer in Indonesia: 2,000 SKUs in 20 brands (SKT, SKM, SPM), 50,000 outlets, 1,000 distributors, 25 sales areas in 5 regions, and 1.5 million sales order lines from January 2019 to August 2025.
Every value is generated from a fixed hash, so every browser builds exactly the same rows.
All names and numbers are synthetic.

| File | What it is |
|---|---|
| `index.html` | The lab page |
| `00_setup_source.sql` | Builds the `source` schema (operational tables) and the two `lab` tables used for the pruning exercise |
| `catchup/catchup_before_day2.sql` | Every Day 1 table (bronze, silver, gold); the Build button runs it after `00_setup_source.sql` |
| `table_docs.json` | Description, primary key and foreign keys of every training table, shown in the Schema panel and the ERD |

The same scripts also run in the DuckDB CLI: `duckdb training.duckdb -f 00_setup_source.sql`.

## Requirements

A recent Chrome or Edge with about 2 GB of free memory, and access to `cdn.jsdelivr.net`, where the page loads DuckDB-WASM (about 7 MB download, cached after the first visit).
