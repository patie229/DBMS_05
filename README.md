# DBMS_05 – From Schema to Data: DDL and DML in Practice

**Module:** Databases · THGA Bochum  
**Lecturer:** Stephan Bökelmann · <sboekelmann@ep1.rub.de>  
**Repository:** <https://github.com/MaxClerkwell/DBMS_05>  
**Prerequisites:** DBMS_01, DBMS_02, DBMS_03, DBMS_04, Lecture 05 (SQL I – DDL & DML)  
**Duration:** 90 minutes

---

## Learning Objectives

After completing this exercise you will be able to:

- Choose appropriate **SQL data types** for a given domain and justify the choice
- Write **`CREATE TABLE`** statements with column and table constraints
  (`PRIMARY KEY`, `FOREIGN KEY`, `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`)
- Declare **referential actions** (`ON DELETE`, `ON UPDATE`) and argue for the
  correct choice per relationship
- Use **`ALTER TABLE`** to add, drop, and modify columns and constraints
- Write **`INSERT`**, **`UPDATE`**, and **`DELETE`** statements — including
  multi-row inserts and updates with subqueries
- Protect destructive DML with **`BEGIN` / `ROLLBACK` / `COMMIT`** and explain
  why Autocommit is dangerous in practice

**After completing this exercise you should be able to answer the following questions independently:**

- Why is `NUMERIC(p,s)` mandatory for monetary values, while `REAL` is not?
- What is the difference between a column constraint and a table constraint —
  and when must a table constraint be used?
- Why does a `CHECK` constraint never reject a `NULL` value?
- What is the effect of a missing `WHERE` clause in `UPDATE` and `DELETE`?

---

## Check Prerequisites

```bash
sqlite3 --version
git --version
```

> You should see two version strings — SQLite 3.x and Git 2.x.
> If SQLite is missing:
>
> ```bash
> sudo apt-get install -y sqlite3   # Debian / Ubuntu
> brew install sqlite3              # macOS
> ```

> **Screenshot 1:** Take a screenshot of your terminal showing both
> successful version checks and insert it here.
>
> `[insert screenshot]`
> <img width="682" height="483" alt="Capture d’écran 2026-05-27 à 00 27 37" src="https://github.com/user-attachments/assets/6308d2a3-f1d3-4d61-81e8-79420c060144" />


---

## 0 – Fork and Clone the Repository

**Step 1 – Fork on GitHub:**  
Navigate to <https://github.com/MaxClerkwell/DBMS_05> and click **Fork**.
Keep the default settings and confirm.

**Step 2 – Clone your fork:**

```bash
git clone git@github.com:<your-username>/DBMS_05.git
cd DBMS_05
ls
```

> You should see only the `README.md`. You will create all further files
> yourself during this exercise.

---

## 1 – The Domain: A Municipal Library

A small municipal library manages its collection, members, and lending
transactions in a relational database. The library needs to track:

- **Books** — each identified by its ISBN, with a title, publication year,
  publisher, and a recommended lending price per day in euro.
- **Copies** — a book can exist in multiple physical copies, each stored at a
  specific shelf location.
- **Members** — registered with name, date of birth, e-mail address, and the
  date they joined the library.
- **Loans** — a member borrows a specific copy on a given date. The return date
  is recorded when the copy is handed back; until then it remains unknown.

The entity-relationship structure is deliberately given to you so that this
exercise can focus entirely on DDL and DML. Your task is to implement this
schema correctly in SQL.

### The Relations

| Relation    | Attributes (informal)                                                               | Primary Key           |
|-------------|-------------------------------------------------------------------------------------|-----------------------|
| `buch`      | isbn, titel, erscheinungsjahr, verlag, tagesgebuehr (in €)                         | isbn                  |
| `exemplar`  | exemplar_id, isbn (FK), standort                                                    | exemplar_id           |
| `mitglied`  | mitglied_id, nachname, vorname, geburtsdatum, email, beitritt_datum                 | mitglied_id           |
| `ausleihe`  | ausleihe_id, exemplar_id (FK), mitglied_id (FK), ausleihe_datum, rueckgabe_datum   | ausleihe_id           |

### Task 1 – Identify the Correct Data Types

| Attribute              | Your Type      | Justification |
|------------------------|----------------|---------------|
| isbn                   | `TEXT`         | ISBN-13 contains hyphens (`978-3-423-08733-2`); it is a structured string, not a number. |
| titel                  | `TEXT`         | Variable-length string. |
| erscheinungsjahr       | `INTEGER`      | Whole number; allows numeric comparisons (`< 1960`) and arithmetic. |
| verlag                 | `TEXT`         | Publisher name, free-form string. |
| tagesgebuehr           | `NUMERIC(6,2)` | Monetary value; exact decimal precision required to avoid floating-point errors. |
| exemplar_id            | `INTEGER`      | Artificial surrogate key, auto-increment via `INTEGER PRIMARY KEY`. |
| standort               | `TEXT`         | Alphanumeric shelf code (`A-01-3`). |
| mitglied_id            | `INTEGER`      | Artificial surrogate key. |
| nachname               | `TEXT`         | Free-form string. |
| vorname                | `TEXT`         | Free-form string. |
| geburtsdatum           | `DATE`         | Pure date; enables `julianday()` calculations and chronological comparisons. |
| email                  | `TEXT`         | String; must be unique across members. |
| beitritt_datum         | `DATE`         | Membership date, defaults to `CURRENT_DATE`. |
| ausleihe_id            | `INTEGER`      | Artificial surrogate key. |
| ausleihe_datum         | `DATE`         | Loan start date. |
| rueckgabe_datum        | `DATE`         | Return date; nullable (NULL = loan still open). |

### Questions for Task 1

**Question 1.1:** `tagesgebuehr` could be stored as `REAL`. Give a concrete
example — using arithmetic — of why `REAL` would produce an incorrect result
for a lending fee calculation. Which type must be used instead?

> **Answer:** `REAL` (IEEE 754 floating point) cannot represent most finite
> decimal numbers exactly. For example, a 30-day loan at €0.10/day should
> cost exactly €3.00, but in floating point arithmetic:
>
> ```sql
> SELECT 0.1 * 30;       -- Result: 3.0000000000000004
> SELECT 0.1 + 0.2;      -- Result: 0.30000000000000004
> ```
>
> Across thousands of transactions these errors accumulate and produce
> visible discrepancies in financial reports. The correct type is
> `NUMERIC(6,2)`, which stores values in exact decimal form and guarantees
> that monetary arithmetic remains exact.

**Question 1.2:** `rueckgabe_datum` must be nullable. Explain what `NULL` means
in this specific context. Is `NULL` the same as "zero days"? Justify with
reference to the three-valued logic of SQL.

> **Answer:** `NULL` here means **"unknown / not yet recorded"** — the book
> is still on loan and the return date does not exist yet. It is **not** the
> same as zero days, which would mean "returned instantly on the day of the
> loan" — a defined and meaningful value.
>
> SQL uses three-valued logic: any comparison involving `NULL` returns
> `UNKNOWN`, not `TRUE` or `FALSE`. Therefore `NULL = NULL` is `UNKNOWN`,
> not `TRUE`. This is why we must write `rueckgabe_datum IS NULL` (a
> dedicated predicate) instead of `rueckgabe_datum = NULL`, which would
> never match anything.

**Question 1.3:** `beitritt_datum` should default to today's date when no value
is provided. Write the `DEFAULT` expression you would use and explain why this
is preferable to always supplying the date explicitly in the application.

> **Answer:**
>
> ```sql
> beitritt_datum DATE NOT NULL DEFAULT CURRENT_DATE
> ```
>
> Three reasons this is preferable to application-side defaults:
> 1. **Single source of truth** — if multiple applications (web, mobile,
>    import scripts) insert members, all of them get the same default
>    without code duplication.
> 2. **Clock consistency** — `CURRENT_DATE` uses the database server's
>    clock, avoiding divergences from client time zones or wrong system
>    clocks.
> 3. **Robustness** — if the application forgets to send the date, the
>    database fills it automatically instead of raising a `NOT NULL`
>    violation.

---

## 2 – DDL: Create the Schema

### Task 2a – Write schema.sql

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE buch (
    isbn              TEXT          PRIMARY KEY,
    titel             TEXT          NOT NULL,
    erscheinungsjahr  INTEGER       NOT NULL,
    verlag            TEXT          NOT NULL,
    tagesgebuehr      NUMERIC(6,2)  NOT NULL CHECK (tagesgebuehr > 0)
);

CREATE TABLE exemplar (
    exemplar_id  INTEGER  PRIMARY KEY,
    isbn         TEXT     NOT NULL,
    standort     TEXT     NOT NULL,
    FOREIGN KEY (isbn) REFERENCES buch(isbn)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE mitglied (
    mitglied_id     INTEGER  PRIMARY KEY,
    nachname        TEXT     NOT NULL,
    vorname         TEXT     NOT NULL,
    geburtsdatum    DATE     NOT NULL,
    email           TEXT     NOT NULL UNIQUE,
    beitritt_datum  DATE     NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE ausleihe (
    ausleihe_id      INTEGER  PRIMARY KEY,
    exemplar_id      INTEGER  NOT NULL,
    mitglied_id      INTEGER  NOT NULL,
    ausleihe_datum   DATE     NOT NULL,
    rueckgabe_datum  DATE,
    FOREIGN KEY (exemplar_id) REFERENCES exemplar(exemplar_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (mitglied_id) REFERENCES mitglied(mitglied_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK (rueckgabe_datum IS NULL OR rueckgabe_datum >= ausleihe_datum)
);
```

### Task 2b – Load the Schema and Verify

```bash
sqlite3 bibliothek.db < schema.sql
sqlite3 bibliothek.db ".tables"
sqlite3 bibliothek.db ".schema"
```

> Expected tables: `ausleihe  buch  exemplar  mitglied`

> **Screenshot 2:** Take a screenshot showing the `.tables` and `.schema`
> output in your terminal.
>
> `[insert screenshot]`
> <img width="682" height="483" alt="Capture d’écran 2026-05-27 à 00 35 11" src="https://github.com/user-attachments/assets/7ae8f3b8-75e4-48ee-88b7-2664ebabc80b" />
> <img width="731" height="693" alt="Capture d’écran 2026-05-27 à 00 36 23" src="https://github.com/user-attachments/assets/3e98d449-1b6a-4bd1-a246-be7e762a0459" />




### Task 2c – Test Constraints

> **Test A** — `INSERT INTO buch VALUES ('000-0-0000-0000-0', 'Fehlertest', 2024, 'Verlag X', -1.50);`  
> **Result:** `Error: CHECK constraint failed: tagesgebuehr > 0`  
> The `CHECK (tagesgebuehr > 0)` constraint rejects the negative value.
>
> **Test B** — `INSERT INTO mitglied (nachname, vorname, geburtsdatum) VALUES ('Mustermann', 'Max', '2000-01-01');`  
> **Result:** `Error: NOT NULL constraint failed: mitglied.email`  
> The `email` column is `NOT NULL` and no value was supplied.
>
> **Test C** — `INSERT INTO ausleihe VALUES (1, 1, 1, '2026-05-10', '2026-05-01');`  
> **Result:** `Error: CHECK constraint failed: rueckgabe_datum IS NULL OR rueckgabe_datum >= ausleihe_datum`  
> The table-level CHECK constraint rejects a return date earlier than the loan date.

### Questions for Task 2

**Question 2.1:** The `CHECK` on `rueckgabe_datum` was written as a table
constraint rather than a column constraint. Why is a column constraint
insufficient here?

> **Answer:** The constraint `rueckgabe_datum >= ausleihe_datum` compares
> **two different columns** of the same row. A column constraint can only
> reference the column on which it is declared — it cannot mention other
> columns. As soon as a constraint involves more than one column, it must
> be declared at the table level (after the column list, or via
> `ALTER TABLE ADD CONSTRAINT`).

**Question 2.2:** You chose `ON DELETE RESTRICT` for all foreign keys.
Describe a realistic alternative: for which relationship would `ON DELETE
CASCADE` be appropriate instead, and why?

> **Answer:** For the relationship `ausleihe → mitglied`, `ON DELETE
> CASCADE` could be appropriate in a **GDPR / right-to-be-forgotten**
> scenario: when a member requests deletion of all their personal data,
> their loan history is automatically erased as well.
>
> However, `RESTRICT` remains the safer default because historical loans
> may contain accounting data (billing, statistics) that must legally be
> retained, and accidentally deleting a member would wipe their entire
> history without warning. A realistic compromise is to **anonymize** the
> member (replace name/email with empty values) while keeping
> `ON DELETE RESTRICT`.

**Question 2.3:** `email` is declared `UNIQUE`. According to the SQL standard,
how many `NULL` values may a `UNIQUE` column contain? Explain using the
three-valued logic of SQL.

> **Answer:** According to the SQL standard, **multiple `NULL` values are
> allowed** in a `UNIQUE` column. Most DBMSs (SQLite, PostgreSQL, Oracle,
> MySQL) follow this rule.
>
> The reason lies in three-valued logic: `UNIQUE` forbids two rows from
> having the **same** value. But `NULL = NULL` returns `UNKNOWN`, not
> `TRUE`. Two `NULL`s are therefore not considered equal and do not
> conflict with the uniqueness constraint.
>
> **Notable exception:** SQL Server (Microsoft) historically forbids more
> than one `NULL` in a `UNIQUE` column, contrary to the standard.

---

## 3 – DML: Populate and Modify Data

### Task 3a – Write data.sql

```sql
PRAGMA foreign_keys = ON;

-- Books
INSERT INTO buch VALUES ('978-3-423-08733-2', 'Steppenwolf',     1927, 'dtv',      0.50);
INSERT INTO buch VALUES ('978-3-518-36893-4', 'Homo Faber',      1957, 'Suhrkamp', 0.50);
INSERT INTO buch VALUES ('978-3-257-20456-6', 'Der Vorleser',    1995, 'Diogenes', 0.75);
INSERT INTO buch VALUES ('978-3-596-18296-4', 'Das Parfum',      1985, 'Fischer',  0.75);
INSERT INTO buch VALUES ('978-3-423-13571-9', 'Die Verwandlung', 1915, 'dtv',      0.30);

-- Copies
INSERT INTO exemplar VALUES (1, '978-3-423-08733-2', 'A-01-3');
INSERT INTO exemplar VALUES (2, '978-3-423-08733-2', 'A-01-4');
INSERT INTO exemplar VALUES (3, '978-3-518-36893-4', 'A-02-1');
INSERT INTO exemplar VALUES (4, '978-3-257-20456-6', 'B-01-7');
INSERT INTO exemplar VALUES (5, '978-3-596-18296-4', 'B-02-2');
INSERT INTO exemplar VALUES (6, '978-3-423-13571-9', 'A-03-1');

-- Members (DEFAULT for beitritt_datum except Klara Sommer)
INSERT INTO mitglied (nachname, vorname, geburtsdatum, email)
VALUES ('Berger',   'Jonas', '2001-04-12', 'jonas.berger@mail.de');

INSERT INTO mitglied (nachname, vorname, geburtsdatum, email, beitritt_datum)
VALUES ('Sommer',   'Klara', '1985-11-30', 'klara.sommer@web.de', '2019-03-15');

INSERT INTO mitglied (nachname, vorname, geburtsdatum, email)
VALUES ('Hartmann', 'Lea',   '1998-07-08', 'lea.hartmann@example.com');

-- Loans
INSERT INTO ausleihe VALUES (1, 1, 1, '2026-05-01', '2026-05-10');
INSERT INTO ausleihe VALUES (2, 3, 2, '2026-05-05', NULL);
INSERT INTO ausleihe VALUES (3, 4, 1, '2026-05-12', NULL);
INSERT INTO ausleihe VALUES (4, 6, 3, '2026-04-20', '2026-04-28');
```

```bash
sqlite3 bibliothek.db < data.sql
```

Verify row counts:

```sql
SELECT 'buch',     COUNT(*) FROM buch
UNION ALL SELECT 'exemplar',  COUNT(*) FROM exemplar
UNION ALL SELECT 'mitglied',  COUNT(*) FROM mitglied
UNION ALL SELECT 'ausleihe',  COUNT(*) FROM ausleihe;
```

> Expected: 5, 6, 3, 4. ✓ All counts match.

### Task 3b – UPDATE Statements

```sql
PRAGMA foreign_keys = ON;

-- 1. Rename publisher dtv
BEGIN;
UPDATE buch
SET    verlag = 'Deutscher Taschenbuch Verlag'
WHERE  verlag = 'dtv';
SELECT isbn, titel, verlag FROM buch WHERE verlag LIKE 'Deutscher%';
COMMIT;

-- 2. Record the return of copy 3 (loan 2)
BEGIN;
UPDATE ausleihe
SET    rueckgabe_datum = CURRENT_DATE
WHERE  ausleihe_id = 2;
SELECT * FROM ausleihe WHERE ausleihe_id = 2;
COMMIT;

-- 3. Raise the daily fee for books published before 1960 by €0.10
BEGIN;
UPDATE buch
SET    tagesgebuehr = tagesgebuehr + 0.10
WHERE  erscheinungsjahr < 1960;
SELECT isbn, titel, erscheinungsjahr, tagesgebuehr
FROM   buch ORDER BY erscheinungsjahr;
COMMIT;
```

### Task 3c – DELETE Statements

```sql
PRAGMA foreign_keys = ON;

-- 1. Remove loans returned more than 30 days ago
BEGIN;
DELETE FROM ausleihe
WHERE  rueckgabe_datum IS NOT NULL
  AND  julianday(CURRENT_DATE) - julianday(rueckgabe_datum) > 30;
SELECT * FROM ausleihe;
COMMIT;

-- 2. Attempt to delete exemplar 3 — expected to fail
BEGIN;
DELETE FROM exemplar WHERE exemplar_id = 3;
-- Error: FOREIGN KEY constraint failed
-- (loan 2 still references exemplar 3 via ON DELETE RESTRICT)
ROLLBACK;

-- 3. Delete loans for exemplar 3 first, then the exemplar itself
BEGIN;
DELETE FROM ausleihe WHERE exemplar_id = 3;
DELETE FROM exemplar WHERE exemplar_id = 3;
SELECT * FROM exemplar;
COMMIT;
```

### Questions for Task 3

**Question 3.1:** The multi-table UPDATE in Task 3b.1 (renaming the publisher)
works because all affected rows are in the same table. Why can a standard SQL
`UPDATE` not update rows in two different tables simultaneously, and what would
you use instead in a production system?

> **Answer:** A standard SQL `UPDATE` statement can only modify **one
> table** at a time. This is a consequence of relational algebra: each
> relation is an independent entity with its own constraints, and atomic
> operations are defined per table.
>
> In production systems, use one of the following instead:
> - **Multiple `UPDATE` statements wrapped in a transaction** (`BEGIN; …;
>   COMMIT;`) to guarantee atomicity across tables.
> - **`ON UPDATE CASCADE`** on foreign keys — already in place in our
>   schema, so updates to primary keys propagate automatically.
> - **Stored procedures or triggers** for more complex propagation logic.

**Question 3.2:** Task 3b.3 raises the fee for books published before 1960
by 10 cents. Write the equivalent statement using `NUMERIC` arithmetic:
`tagesgebuehr = tagesgebuehr + 0.10`. Would the same statement work correctly
with `REAL`? Explain the risk.

> **Answer:**
>
> ```sql
> UPDATE buch SET tagesgebuehr = tagesgebuehr + 0.10
> WHERE erscheinungsjahr < 1960;
> ```
>
> With `NUMERIC(6,2)`, the result is exact: 0.50 → 0.60, 0.30 → 0.40.
>
> With `REAL`, the risk is **accumulating floating-point errors**. A
> single addition might be invisible, but after several repeated executions
> (annual price adjustments, compound calculations) the stored value drifts:
> `0.50 + 0.10 = 0.6000000000000001`. Across thousands of records and
> recurring batch jobs, these tiny errors aggregate into visible
> discrepancies on financial reports.

**Question 3.3:** Task 3c.1 deletes loans where the return date is more than
30 days ago. A `DELETE` without a `WHERE` clause would delete all loans.
Describe the operational consequence and explain how `BEGIN` / `ROLLBACK`
protects against this mistake.

> **Answer:** `DELETE FROM ausleihe;` without a `WHERE` clause wipes the
> entire table. Under autocommit, the deletion is **immediate and
> irreversible**. Recovery requires restoring from a backup, which costs
> downtime and loses every transaction since the last backup.
>
> Wrapping the statement in a transaction provides a safety net:
>
> ```sql
> BEGIN;
> DELETE FROM ausleihe;   -- 4 rows deleted, but only inside the transaction
> SELECT COUNT(*) FROM ausleihe;  -- 0: clear sign of mistake
> ROLLBACK;               -- restore: back to the original 4 rows
> ```
>
> As long as `COMMIT` has not been executed, `ROLLBACK` reverts the entire
> transaction. The golden rule for interactive DML: **always wrap
> destructive statements in `BEGIN`, verify with `SELECT`, then `COMMIT`.**

---

## 4 – ALTER TABLE: Evolving the Schema

### Task 4a – Add a Column

```sql
ALTER TABLE mitglied ADD COLUMN telefon TEXT;
```

### Task 4b – Add a Named Constraint

SQLite does not support `ADD CONSTRAINT` via `ALTER TABLE`. The standard SQL
statement (shown for reference) and the SQLite four-step workaround are:

```sql
-- Standard SQL (PostgreSQL etc.):
--   ALTER TABLE buch
--     ADD CONSTRAINT buch_jahr_plausibel
--     CHECK (erscheinungsjahr BETWEEN 1450 AND 2100);

-- SQLite workaround:
BEGIN;
CREATE TABLE buch_new (
    isbn              TEXT          PRIMARY KEY,
    titel             TEXT          NOT NULL,
    erscheinungsjahr  INTEGER       NOT NULL,
    verlag            TEXT          NOT NULL,
    tagesgebuehr      NUMERIC(6,2)  NOT NULL CHECK (tagesgebuehr > 0),
    CONSTRAINT buch_jahr_plausibel
        CHECK (erscheinungsjahr BETWEEN 1450 AND 2100)
);
INSERT INTO buch_new SELECT * FROM buch;
DROP TABLE buch;
ALTER TABLE buch_new RENAME TO buch;
COMMIT;
```

### Task 4c – Change a Column Type

```sql
-- Standard SQL:
--   ALTER TABLE exemplar
--     ALTER COLUMN standort SET DATA TYPE VARCHAR(10);

-- SQLite workaround (same four-step procedure):
BEGIN;
CREATE TABLE exemplar_new (
    exemplar_id  INTEGER     PRIMARY KEY,
    isbn         TEXT        NOT NULL,
    standort     VARCHAR(10) NOT NULL,
    FOREIGN KEY (isbn) REFERENCES buch(isbn)
        ON DELETE RESTRICT ON UPDATE CASCADE
);
INSERT INTO exemplar_new SELECT * FROM exemplar;
DROP TABLE exemplar;
ALTER TABLE exemplar_new RENAME TO exemplar;
COMMIT;
```

### Questions for Task 4

**Question 4.1:** `ALTER TABLE mitglied ADD COLUMN telefon TEXT` adds a
nullable column. Why is this simpler than adding a `NOT NULL` column to an
already-populated table? What steps would be needed for a `NOT NULL` column?

> **Answer:** Adding a nullable column is instant: existing rows
> automatically receive `NULL` for the new column. No validation, no data
> migration required.
>
> Adding a `NOT NULL` column to a populated table needs three steps:
> 1. `ALTER TABLE ... ADD COLUMN telefon TEXT;` (initially nullable, since
>    `NOT NULL` would fail on existing rows that have no value).
> 2. `UPDATE ... SET telefon = '<default value>';` for all existing rows.
> 3. Rebuild the table with `NOT NULL` on the column (in SQLite, this means
>    the four-step procedure: create new, copy, drop old, rename).
>
> Therefore, prefer nullable columns whenever no meaningful default value
> exists.

**Question 4.2:** SQLite's limited `ALTER TABLE` support is a deliberate
design decision. What does this tell you about the trade-off between a
lightweight embedded database and a full-featured server database system?
Name one scenario where SQLite is the right choice and one where it is not.

> **Answer:** SQLite chose **simplicity over feature completeness**: no
> server process, no configuration, the entire database in a single file.
> The price is limited schema-evolution capabilities, judged less critical
> for SQLite's target use cases.
>
> **SQLite is the right choice** for: mobile apps (Android, iOS),
> application configuration files, prototyping, unit tests, file formats
> (Firefox stores bookmarks in SQLite), single-user analytical tools.
>
> **SQLite is not appropriate** for: high-concurrency web applications
> with many simultaneous writers, mission-critical data needing
> replication, frequently evolving schemas, complex audit requirements.
> A full server DBMS (PostgreSQL, Oracle, etc.) is required there.

---

## 5 – Transactions: Borrowing as an Atomic Operation

### Task 5a – Simulate a Safe Lending Transaction

```sql
PRAGMA foreign_keys = ON;

BEGIN;

-- Step 1: verify the copy is available (no open loan)
SELECT COUNT(*) AS open_loans
FROM   ausleihe
WHERE  exemplar_id = 5
  AND  rueckgabe_datum IS NULL;

-- Step 2: insert the loan (only proceed if the count above is 0)
INSERT INTO ausleihe (ausleihe_id, exemplar_id, mitglied_id, ausleihe_datum)
VALUES (5, 5, 3, CURRENT_DATE);

COMMIT;

SELECT * FROM ausleihe WHERE ausleihe_id = 5;
```

> **Screenshot 3:** Take a screenshot showing the inserted row.
>
> `[insert screenshot]`
> <img width="731" height="693" alt="Capture d’écran 2026-05-27 à 00 41 18" src="https://github.com/user-attachments/assets/9a103a20-4574-4a03-b92a-8951f5fdf8f9" />



### Task 5b – Simulate a Rollback

```sql
BEGIN;
UPDATE ausleihe SET rueckgabe_datum = NULL WHERE ausleihe_id = 2;
INSERT INTO ausleihe (ausleihe_id, exemplar_id, mitglied_id, ausleihe_datum)
VALUES (6, 3, 1, CURRENT_DATE);
ROLLBACK;

-- Verify
SELECT rueckgabe_datum FROM ausleihe WHERE ausleihe_id = 2;
SELECT COUNT(*) FROM ausleihe WHERE ausleihe_id = 6;
```

> **What I see:**  
> - `rueckgabe_datum` for `ausleihe_id = 2` is back to its original value
>   (the actual return date).  
> - `COUNT(*)` for `ausleihe_id = 6` is `0` — the inserted row was never
>   persisted.
>
> **Why `ROLLBACK` reversed both changes:** `BEGIN` opens a transaction
> that isolates all subsequent modifications in a temporary journal.
> `ROLLBACK` discards that journal, reverting the database to exactly the
> state it had before `BEGIN`. This is the **atomicity** property (the *A*
> in ACID): a transaction is all-or-nothing. There is no intermediate
> state where only the UPDATE persisted but not the INSERT — or vice
> versa.

### Questions for Task 5

**Question 5.1:** In the lending scenario, why is it important that the
availability check and the insert happen inside the same transaction?
What could go wrong if they ran as separate Autocommit statements?

> **Answer:** With two separate autocommit statements, a **race condition**
> can occur:
> 1. Our `SELECT COUNT(*)` returns 0 — the copy appears available.
> 2. A few milliseconds pass.
> 3. Another user concurrently runs an `INSERT` for the same copy.
> 4. Our `INSERT` runs — now the same copy is on loan to two members at
>    once.
>
> This is known as a **lost update** or **phantom read**. Inside a single
> transaction with appropriate isolation (SQLite uses serializable
> transactions by default), the lock placed by the `SELECT` prevents
> concurrent modifications until `COMMIT`, eliminating the race.

**Question 5.2:** The lecture states: "Ein fehlendes `WHERE` aktualisiert
alle Zeilen." Write the single most dangerous `UPDATE` statement possible
on this database and explain the damage it would cause. Then explain how
`BEGIN` / `ROLLBACK` would allow you to recover.

> **Answer:**
>
> ```sql
> UPDATE buch SET tagesgebuehr = 0;
> ```
>
> All books become free. The library loses all future lending revenue, and
> the original per-book prices are gone unless a backup exists. Recovery
> requires restoring from backup and replaying every transaction since
> then — potentially hours of downtime and lost data.
>
> Equally dangerous: `UPDATE ausleihe SET rueckgabe_datum = NULL;` would
> reopen every historical loan, making it impossible to know which copies
> are actually available.
>
> **BEGIN / ROLLBACK as protection:**
>
> ```sql
> BEGIN;
> UPDATE buch SET tagesgebuehr = 0;   -- 5 rows updated
> SELECT * FROM buch;                  -- "Oh no, that's wrong"
> ROLLBACK;                            -- revert to original state
> ```
>
> As long as the transaction is not committed, `ROLLBACK` undoes
> everything.

**Question 5.3:** Autocommit is convenient for read-only queries (`SELECT`).
Is it also safe for DML in an interactive session? Give a concrete example
from this exercise where Autocommit would have caused irreversible data loss.

> **Answer:** **No.** Under autocommit, every DML statement is committed
> immediately, with no undo possible.
>
> **Concrete example from this exercise:** in Task 3c.1, the intended
> `DELETE` removes only loans returned more than 30 days ago:
>
> ```sql
> DELETE FROM ausleihe
> WHERE rueckgabe_datum IS NOT NULL
>   AND julianday(CURRENT_DATE) - julianday(rueckgabe_datum) > 30;
> ```
>
> If someone forgets the second condition by mistake:
>
> ```sql
> DELETE FROM ausleihe WHERE rueckgabe_datum IS NOT NULL;
> ```
>
> Under autocommit, **all completed loans are gone instantly** — the entire
> lending history of the library is wiped out, with serious consequences
> for statistics, accounting audits, and GDPR records. In an explicit
> transaction, a `ROLLBACK` would have undone it. The rule: **always
> `BEGIN` before destructive DML in interactive sessions, verify the
> effect with `SELECT`, and only then `COMMIT`.**

---

## 6 – Reflection

**Question A – Type discipline:**  
The lecture warns against using `TEXT` for everything. Looking at the
`buch` table: which column would be most tempting to store as `TEXT` when
it should be a more specific type, and what concrete query would break or
produce wrong results if the wrong type were used?

> **Answer:** The most tempting column to mis-type is `erscheinungsjahr`,
> which one might store as `TEXT` since years "look like" labels.
>
> **A query that breaks:**
>
> ```sql
> SELECT titel FROM buch WHERE erscheinungsjahr < 1960;
> ```
>
> With `TEXT`, comparisons are lexicographic, not numeric:
> - `'1957' < '1960'` → TRUE (correct, by accident)
> - `'987'  < '1960'` → TRUE (correct, again by accident)
> - `'2'    < '1960'` → FALSE (wrong! `'2'` is lexicographically greater)
>
> Furthermore, arithmetic fails silently in SQLite due to type affinity:
> `erscheinungsjahr + 1` produces `19571` (string concatenation), not
> `1958`. Using `INTEGER` enforces numeric semantics for comparisons and
> arithmetic.

**Question B – DDL as documentation:**  
A colleague reads your `schema.sql` and says: "Constraints slow down inserts
— I'd rather check these rules in the application." Give two concrete
reasons why enforcing constraints in the database is preferable to
enforcing them only in application code.

> **Answer:**
> 1. **Single source of truth.** A database is often accessed by multiple
>    applications: a web frontend, a mobile app, batch import scripts, BI
>    tools. A rule encoded only in the web frontend's Java code does not
>    protect against a malformed `INSERT` from a Python migration script
>    or an analyst's direct SQL query. Database constraints apply to **all
>    paths** of data modification.
> 2. **The schema is the documentation.** Reading a well-written
>    `schema.sql` is equivalent to reading a domain specification. The
>    constraints (`tagesgebuehr > 0`, `email UNIQUE`, `CHECK
>    rueckgabe_datum >= ausleihe_datum`) encode business rules in a
>    machine-readable, self-verified form. A new developer understands the
>    domain rules without reading any application code, and the constraints
>    cannot drift out of sync with the data the way comments or wikis can.

**Question C – NULL semantics in lending:**  
In `ausleihe`, `rueckgabe_datum IS NULL` means "currently on loan". Could
this semantic be expressed without using `NULL` — e.g. by using a status
column instead? What are the trade-offs?

> **Answer:** Yes, a `status` column can replace the NULL semantics:
>
> ```sql
> status TEXT NOT NULL DEFAULT 'open'
>        CHECK (status IN ('open', 'returned'))
> ```
>
> **Advantages of the status column:**
> - More readable: `WHERE status = 'open'` is clearer than
>   `WHERE rueckgabe_datum IS NULL`.
> - Extensible to additional states (`'lost'`, `'overdue'`, `'reserved'`)
>   without schema changes.
> - Removes ambiguity about what `NULL` means.
>
> **Drawbacks:**
> - **Redundancy** with `rueckgabe_datum`: if the return date is non-NULL,
>   the status must be `'returned'`. This creates two sources of truth
>   that must be kept in sync via triggers or cross-column constraints.
> - One extra column to store and index.
>
> **Pragmatic compromise:** keep `rueckgabe_datum` as the authoritative
> field (it already encodes both "loan open" and "loan returned, with
> date"), and derive the status on the fly in queries or views when
> needed.

**Question D – `TRUNCATE` vs. `DELETE`:**  
If you wanted to reset the entire database and reload the sample data from
scratch, you would need to empty all four tables. Can you use `TRUNCATE`
in SQLite? What alternative would you use, and in what order must the tables
be emptied to respect foreign key constraints?

> **Answer:** **No, SQLite does not support `TRUNCATE`.** The equivalent
> is `DELETE FROM <table>;` without a `WHERE` clause. SQLite recognizes
> this special case and applies a "truncate optimization" internally, but
> the syntax is `DELETE`.
>
> **Deletion order (respecting FK dependencies):**
> 1. `DELETE FROM ausleihe;` — depends on `exemplar` and `mitglied`.
> 2. `DELETE FROM exemplar;` — depends on `buch`.
> 3. `DELETE FROM mitglied;` — independent.
> 4. `DELETE FROM buch;` — independent.
>
> This is the reverse of the creation order. Without this order, the
> `ON DELETE RESTRICT` constraints raise foreign-key violations.
>
> For test scripts (never in production), foreign keys can be temporarily
> disabled to delete in any order:
>
> ```sql
> PRAGMA foreign_keys = OFF;
> DELETE FROM ausleihe;
> DELETE FROM exemplar;
> DELETE FROM mitglied;
> DELETE FROM buch;
> PRAGMA foreign_keys = ON;
> ```

> **Screenshot 4:** Take a screenshot showing the output of the row-count
> verification from Task 3a after completing all DML tasks, with
> `.headers on` and `.mode column` active.
>
> `[insert screenshot]`
> <img width="731" height="693" alt="Capture d’écran 2026-05-27 à 00 51 46" src="https://github.com/user-attachments/assets/00bce982-164b-4fe9-b2ec-0a1b110af21b" />


---

## Bonus Tasks

### Bonus 1 — `INSERT INTO … SELECT`

```sql
INSERT INTO exemplar (isbn, standort)
SELECT e.isbn,
       'Neu-' || MIN(e.standort) AS new_standort
FROM   exemplar e
JOIN   ausleihe a ON a.exemplar_id = e.exemplar_id
GROUP  BY e.isbn
HAVING COUNT(*) > 1;
```

### Bonus 2 — Open loans with duration

```sql
SELECT m.nachname || ', ' || m.vorname  AS member_name,
       b.titel                          AS book_title,
       CAST(julianday(CURRENT_DATE) - julianday(a.ausleihe_datum) AS INTEGER) 
                                        AS days_borrowed
FROM   ausleihe a
JOIN   exemplar e  ON e.exemplar_id = a.exemplar_id
JOIN   buch     b  ON b.isbn        = e.isbn
JOIN   mitglied m  ON m.mitglied_id = a.mitglied_id
WHERE  a.rueckgabe_datum IS NULL
ORDER  BY days_borrowed DESC;
```

### Bonus 3 — Lending fee invoice

```sql
SELECT m.nachname || ', ' || m.vorname  AS member_name,
       b.titel                          AS book_title,
       a.ausleihe_datum,
       a.rueckgabe_datum,
       ROUND(
         (julianday(a.rueckgabe_datum) - julianday(a.ausleihe_datum))
         * b.tagesgebuehr,
         2)                             AS amount_due_eur
FROM   ausleihe a
JOIN   exemplar e  ON e.exemplar_id = a.exemplar_id
JOIN   buch     b  ON b.isbn        = e.isbn
JOIN   mitglied m  ON m.mitglied_id = a.mitglied_id
WHERE  a.rueckgabe_datum IS NOT NULL
ORDER  BY amount_due_eur DESC;
```

### Bonus 4 — GitHub Actions workflow

```yaml
# .github/workflows/ci.yml
name: CI - Verify schema and data

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-schema:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install SQLite
        run: sudo apt-get update && sudo apt-get install -y sqlite3

      - name: Create database and load schema
        run: sqlite3 bibliothek.db < schema.sql

      - name: Load sample data
        run: sqlite3 bibliothek.db < data.sql

      - name: Verify row counts
        run: |
          BUCH=$(sqlite3 bibliothek.db "SELECT COUNT(*) FROM buch;")
          EXEMPLAR=$(sqlite3 bibliothek.db "SELECT COUNT(*) FROM exemplar;")
          MITGLIED=$(sqlite3 bibliothek.db "SELECT COUNT(*) FROM mitglied;")
          AUSLEIHE=$(sqlite3 bibliothek.db "SELECT COUNT(*) FROM ausleihe;")

          test "$BUCH"     = "5" || (echo "buch != 5"; exit 1)
          test "$EXEMPLAR" = "6" || (echo "exemplar != 6"; exit 1)
          test "$MITGLIED" = "3" || (echo "mitglied != 3"; exit 1)
          test "$AUSLEIHE" = "4" || (echo "ausleihe != 4"; exit 1)

          echo "All row counts verified: 5, 6, 3, 4"
```

---

## Further Reading

- ISO/IEC 9075 (SQL Standard) — official reference; most universities have access
- [SQLite – Core Functions](https://www.sqlite.org/lang_corefunc.html)
- [SQLite – Date and Time Functions](https://www.sqlite.org/lang_datefunc.html)
- [SQLite – Foreign Key Support](https://www.sqlite.org/foreignkeys.html)
- [SQLite – ALTER TABLE Limitations](https://www.sqlite.org/lang_altertable.html)
- Lecture 05 handout – *SQL I: DDL & DML*
