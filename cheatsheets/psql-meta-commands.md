# Cheatsheet — `psql` Meta-Commands

Meta-commands start with `\`, are executed by `psql` (never sent to the server),
and take **no semicolon**.

## Connection & navigation

| Command | Does |
|---|---|
| `\conninfo` | Which database, user, host, port am I on? |
| `\c dbname` | Connect to another database |
| `\c dbname user` | …as another user |
| `\q` | Quit |
| `\! command` | Run a shell command without leaving psql |
| `\cd dir` | Change psql's working directory |

## Listing things

| Command | Lists |
|---|---|
| `\l` / `\l+` | Databases (`+` adds size) |
| `\dt` / `\dt+` | Tables (`+` adds size & description) |
| `\d` | Tables, views, sequences |
| `\d name` | **Describe** one table: columns, types, indexes, constraints, FKs |
| `\d+ name` | …plus storage, stats target, comments |
| `\dv` | Views |
| `\dm` | Materialized views |
| `\di` | Indexes |
| `\ds` | Sequences |
| `\df` | Functions |
| `\dn` | Schemas |
| `\du` | Roles / users |
| `\dp` / `\z` | Table privileges |
| `\dx` | Installed extensions |
| `\dT` | Data types |

Add a pattern to filter: `\dt cust*`, `\df *json*`.

## Output formatting

| Command | Does |
|---|---|
| `\x` | Toggle expanded display (one column per line) |
| `\x auto` | Expand only when the row is too wide — **best setting** |
| `\timing` | Toggle "how long did that take" |
| `\pset null '␀'` | Show NULLs visibly instead of as blank |
| `\pset format csv` | Output as CSV (also `aligned`, `html`, `json`) |
| `\pset pager off` | Stop paging output through `less` |
| `\a` | Toggle aligned/unaligned output |
| `\H` | Toggle HTML output |

## Files & scripts

| Command | Does |
|---|---|
| `\i file.sql` | Execute a file (path relative to your shell's cwd) |
| `\ir file.sql` | Execute a file relative to **the current script's** directory |
| `\o file.txt` | Send all query output to a file; `\o` alone stops |
| `\e` | Open the last query in `$EDITOR`, run it on save |
| `\ef funcname` | Edit a function definition |
| `\g file` | Run the current query and write output to a file |
| `\copy tbl FROM 'f.csv' CSV HEADER` | Client-side bulk load (no server file access needed) |

## Help

| Command | Does |
|---|---|
| `\?` | All meta-commands |
| `\h` | All SQL commands |
| `\h SELECT` | Syntax for one SQL command |
| `\?` variables | psql variables |

## Variables

```
\set myvar 42
SELECT :myvar;               -- substitutes the value
\set tbl customers
SELECT * FROM :tbl;          -- substitutes an identifier
SELECT :'myvar';             -- substitutes as a quoted literal
SELECT :"tbl";               -- substitutes as a quoted identifier
```

Built-ins worth knowing: `:DBNAME`, `:USER`, `:VERSION`, `:ERROR`, `:ROW_COUNT`.

## Command-line flags (before you get to the prompt)

```bash
psql -h host -p 5432 -U user -d db     # explicit connection
psql -c "SELECT 1;"                    # run one statement and exit
psql -f script.sql                     # run a file and exit
psql --csv -c "SELECT * FROM t;"       # CSV output
psql -X                                # ignore ~/.psqlrc (use in scripts!)
psql -v ON_ERROR_STOP=1 -f script.sql  # abort on first error (use in CI!)
psql -1 -f script.sql                  # wrap the whole file in one transaction
psql -E                                # echo the SQL behind every \d command
```

> `-v ON_ERROR_STOP=1` is the most important flag on this page. Without it, a
> failing migration script keeps running every subsequent statement.
>
> `-E` is the most *educational*: it shows you the catalog queries `\d` runs, so
> you learn to query `pg_class` and `pg_attribute` yourself.

## Prompt states

| Prompt | Meaning | Escape |
|---|---|---|
| `db=#` | Ready (superuser) | — |
| `db=>` | Ready (normal user) | — |
| `db-#` | Mid-statement, waiting for `;` | type `;` |
| `db'#` | Unclosed single quote | type `'` |
| `db"#` | Unclosed double quote | type `"` |
| `db(#` | Unclosed parenthesis | type `)` |
| `db$#` | Unclosed dollar quote | type `$$` |
| `db!#` | Transaction aborted | `ROLLBACK;` |

`Ctrl-C` abandons the current input line. `Ctrl-R` searches your history.

## A good `~/.psqlrc`

```
\set QUIET 1
\timing on
\x auto
\pset null '␀'
\pset linestyle unicode
\set COMP_KEYWORD_CASE upper
\set HISTSIZE 100000
\set VERBOSITY verbose
\set PROMPT1 '%[%033[1;32m%]%n@%/%[%033[0m%]%R%# '
\unset QUIET
```

Always pass `-X` in scripts so your personal settings never change a script's
behaviour on someone else's machine.
