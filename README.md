# PT XYZ SQL Lab

A browser-based SQL lab for a two-day training on SQL and dimensional modeling.
It runs [DuckDB](https://duckdb.org) inside the browser tab with DuckDB-WASM: nothing to install, no login, no server, and no data leaves the laptop.

Open it: **https://benhughierznd.github.io/ptxyz-sql-lab/**

## For participants

1. Open the page in a recent Chrome or Edge and wait until the top right says **Ready**.
2. Click **Build PT XYZ data**. It creates the training data in about 15 seconds.
3. Paste SQL into the editor and press **Ctrl+Enter**.
   Select part of the text to run only the selection.
4. Under the editor, every statement gets one line: seconds, rows scanned, row groups scanned, rows returned.
   Seconds and rows scanned come from the DuckDB profiler (the same numbers `EXPLAIN ANALYZE` shows).

The tables live in the browser tab.
If you close the tab, or start a new day, open the page again and use **Catch up** to rebuild every table up to the lab you are starting.
The editor text is kept.

## The data

PT XYZ is a fictional cigarette manufacturer in Indonesia: 2,000 SKUs in 20 brands (SKT, SKM, SPM), 50,000 outlets, 1,000 distributors, 25 sales areas in 5 regions, and 1.5 million sales order lines from January 2019 to August 2025.
Every value is generated from a fixed hash, so every browser builds exactly the same rows.
All names and numbers are synthetic.

| File | What it is |
|---|---|
| `index.html` | The lab page |
| `00_setup_source.sql` | Builds the `source` schema (operational tables) and the two `lab` tables used for the pruning exercise |
| `catchup/*.sql` | Rebuilds bronze, silver and gold up to a given lab |

The same scripts also run in the DuckDB CLI: `duckdb training.duckdb -f 00_setup_source.sql`.

## Requirements

A recent Chrome or Edge with about 2 GB of free memory, and access to `cdn.jsdelivr.net`, where the page loads DuckDB-WASM (about 7 MB download, cached after the first visit).
