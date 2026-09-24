# Day 01 — Installing PostgreSQL & Meeting `psql`

> **Phase** 1 · Foundations
> **Level** Absolute Beginner
> **Time** 90–120 minutes
> **Prerequisites** None. Literally none.
> **New concepts** Server vs client · installing PostgreSQL · `psql` · meta-commands · your first SQL statement · reading an error message

---

## Why this matters

Everything in the next 114 days happens inside a program you are about to
install. If the install is shaky, every later day is shaky. And `psql` — the
terminal client — is the tool you will live in. Engineers who are fluent in
`psql` debug production problems in ninety seconds. Engineers who are not open
a GUI, click around, and guess.

Today you install the thing, connect to it, and type one statement. That's all.
It's a small day on purpose.

---

## Part 1 — What PostgreSQL actually is

PostgreSQL is a **database server**. That word matters.

It is a program that runs continuously in the background on a machine. It holds
data on disk, and it waits for other programs to connect to it over a network
socket and ask it questions. It does not have a window. It does not have a user
interface. It just sits there, listening, usually on **port 5432**.

To talk to it you need a **client** — a separate program that opens a connection
and sends text. That text is SQL.

```
┌──────────────────┐         SQL over TCP          ┌──────────────────────┐
│  client          │ ────────────────────────────► │  PostgreSQL server   │
│  (psql, your     │                               │  (the `postgres`     │
│   app, a GUI)    │ ◄──────────────────────────── │   background process)│
└──────────────────┘         rows back             └──────────┬───────────┘
                                                              │
                                                              ▼
                                                        data on disk
```

Three words you will hear constantly, distinguished now so you never confuse
them later:

| Word | What it means |
|---|---|
| **server** / **instance** / **cluster** | One running PostgreSQL process tree, listening on one port, managing one data directory |
| **database** | One named collection of tables inside that server. A server holds many databases |
| **schema** | A named folder of tables *inside* a database. Default is `public` |

So a single PostgreSQL install can hold many databases, and each database can
hold many schemas, and each schema holds many tables. Today you only need to
know that the nesting exists.

💡 **Note** — "PostgreSQL" and "Postgres" are the same thing. The project accepts
both. Nobody will correct you. "PostgreSQL" is the formal name; "Postgres" is
what people actually say.

🐘 **Postgres-only** — The name is pronounced *POST-gres-cue-ell*. The "SQL"
at the end is a historical leftover from a predecessor called POSTGRES that had
its own query language. You will never need this fact except in conversation.

---

## Part 2 — Installing it

Pick your operating system. Do exactly one of these.

### macOS

The simplest route is Homebrew:

```bash
brew install postgresql@16
brew services start postgresql@16
```

Then make the command-line tools findable. Add this to `~/.zshrc`:

```bash
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
```

(On an Intel Mac the path is `/usr/local/opt/postgresql@16/bin` instead.)
Open a new terminal window so the change takes effect.

Alternative, if you dislike Homebrew: **Postgres.app** from
`https://postgresapp.com` — download, drag to Applications, click Initialize.
It is a genuinely excellent one-click install.

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql     # start automatically on boot
```

### Fedora / RHEL

```bash
sudo dnf install postgresql-server postgresql-contrib
sudo postgresql-setup --initdb
sudo systemctl enable --now postgresql
```

### Windows

Download the installer from
`https://www.postgresql.org/download/windows/` (the EnterpriseDB one).
Run it, accept the defaults, and **write down the password you set for the
`postgres` user** — you will need it every time you connect.

When it finishes, use **SQL Shell (psql)** from the Start menu, or add
`C:\Program Files\PostgreSQL\16\bin` to your `PATH` so `psql` works in
PowerShell.

### Docker (any OS, if you prefer isolation)

```bash
docker run --name pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:16
docker exec -it pg psql -U postgres
```

This is clean and disposable, but be aware: when the container is removed, so is
your data, unless you mount a volume. For a 115-day program, prefer a real
install.

### Verify the install

```bash
psql --version
```

Expected output, something like:

```
psql (PostgreSQL) 16.13
```

Any version 14 or newer is fine for this program. Everything up to Day 100 works
on 13 as well. If this command says "command not found", your `PATH` is wrong —
fix that before continuing. Do not move on with a half-working install.

---

## Part 3 — Connecting with `psql`

`psql` is the official terminal client. Connect:

```bash
psql -U postgres
```

On Linux you may need:

```bash
sudo -u postgres psql
```

because the default install only lets the operating-system user `postgres`
connect as the database user `postgres`.

On success you get a prompt:

```
psql (16.13)
Type "help" for help.

postgres=#
```

Read that prompt carefully — it tells you things:

```
postgres=#
│        │
│        └─ `#` means you are a superuser.  `>` would mean an ordinary user.
└────────── the database you are currently connected to
```

The four pieces of the connection you just made, spelled out:

| Flag | Meaning | Default |
|---|---|---|
| `-h` | host | `localhost` (or a local socket) |
| `-p` | port | `5432` |
| `-U` | user | your operating-system username |
| `-d` | database | same as the username |

So `psql -U postgres` is short for
`psql -h localhost -p 5432 -U postgres -d postgres`.

▶ **Try it** — connect now. Do not read further until you see a prompt.

### If it refuses

| Error | Cause | Fix |
|---|---|---|
| `could not connect to server` | The server isn't running | `brew services start postgresql@16` / `sudo systemctl start postgresql` |
| `role "yourname" does not exist` | You didn't pass `-U postgres` | `psql -U postgres` |
| `password authentication failed` | Wrong password | Windows: the one from the installer. Linux: `sudo -u postgres psql` |
| `command not found: psql` | `PATH` problem | Add the PostgreSQL `bin` directory to `PATH` |

---

## Part 4 — Meta-commands

Inside `psql` there are two kinds of input.

1. **SQL** — sent to the server. Always ends with a semicolon `;`.
2. **Meta-commands** — handled by `psql` itself, never sent to the server.
   Always start with a backslash `\`. **Never** take a semicolon.

Meta-commands are the reason `psql` is worth learning. Here are the ones you
need today.

```
\l              list databases
\c dbname       connect to another database
\dt             list tables in the current database
\d tablename    describe a table (columns, types, indexes, constraints)
\d              list everything (tables, views, sequences)
\du             list users/roles
\conninfo       who am I, where am I connected?
\?              help on meta-commands
\h SELECT       help on the SQL command SELECT
\q              quit
```

▶ **Try it** — run these four, in order, and read the output of each:

```
\conninfo
\l
\du
\?
```

`\l` output looks roughly like this on a fresh install:

```
                              List of databases
   Name    |  Owner   | Encoding | Collate | Ctype |   Access privileges
-----------+----------+----------+---------+-------+-----------------------
 postgres  | postgres | UTF8     | C       | C     |
 template0 | postgres | UTF8     | C       | C     | =c/postgres          +
           |          |          |         |       | postgres=CTc/postgres
 template1 | postgres | UTF8     | C       | C     | =c/postgres          +
           |          |          |         |       | postgres=CTc/postgres
(3 rows)
```

Three databases exist on a brand-new server:

- **`postgres`** — a default database that exists so you have somewhere to
  connect. Nothing important lives here.
- **`template1`** — the template every new database is copied from. If you add
  a table to `template1`, every future database will have it. Don't.
- **`template0`** — a pristine, never-modified backup of `template1`. Used when
  you need a guaranteed-clean starting point.

⚠️ **Trap** — Typing `\dt` right now returns `Did not find any relations.`
That is not an error. It means "this database has no tables", which is true —
you haven't created any. Beginners often read "did not find" as a failure. It
isn't.

### `psql` display settings worth knowing on Day 1

```
\x              toggle expanded display (one column per line) — essential for wide tables
\timing         toggle "how long did that take?" — turn it on and leave it on
\pset null '␀'  show NULLs as a visible character instead of blank
```

▶ **Try it** — run `\timing` now. From here on, every query tells you its
duration. By Day 76 you will care about that number a great deal.

---

## Part 5 — Your first SQL statement

Type this exactly, semicolon included, and press Enter:

```sql
SELECT 'Hello, PostgreSQL';
```

Output:

```
     ?column?
-------------------
 Hello, PostgreSQL
(1 row)
```

You just:

1. sent a SQL statement to the server,
2. which computed a result — one row, one column,
3. and sent it back, which `psql` formatted as a table.

That is the entire model of every interaction for the next 114 days.

`?column?` is PostgreSQL saying "you gave me an expression, not a column from a
table, and you didn't name it, so I don't know what to call this." You will fix
that on Day 4.

### The semicolon

The semicolon ends a statement. Without it, `psql` assumes you are still typing
and the prompt changes:

```
postgres=# SELECT 'Hello'
postgres-#
```

Notice `=#` became `-#`. That dash means **"I am waiting for you to finish."**
Type `;` and press Enter, and it runs.

▶ **Try it** — deliberately forget the semicolon, watch the prompt change, then
finish the statement. Do this once now so you recognise it forever. This is the
single most common source of "psql is frozen" confusion, and it is never frozen.

Other prompt states you will see:

| Prompt | Meaning | Escape |
|---|---|---|
| `=#` | Ready for a new statement | — |
| `-#` | Mid-statement, waiting for `;` | type `;` |
| `'#` | You have an unclosed single quote | type `'` |
| `"#` | You have an unclosed double quote | type `"` |
| `(#` | You have an unclosed parenthesis | type `)` |

If you are lost in any of these, press `Ctrl-C` to abandon the line and start
over.

---

## Part 6 — Reading an error message on purpose

Rule **L5** in `RULES.md` says: break something every day. Start now.

▶ **Try it** — run this, which is wrong:

```sql
SELCT 'oops';
```

```
ERROR:  syntax error at or near "SELCT"
LINE 1: SELCT 'oops';
        ^
```

Three things to notice, because this structure is identical for every error you
will ever see:

1. **`ERROR:`** followed by a short description.
2. **`LINE 1:`** the offending line, echoed back.
3. **`^`** a caret pointing at the exact character where the parser gave up.

The caret is the most useful part and beginners ignore it. It points at where
PostgreSQL *stopped understanding*, which is usually one token after the actual
mistake.

▶ **Try it** — now run something that is valid SQL but refers to something that
doesn't exist:

```sql
SELECT * FROM nonexistent_table;
```

```
ERROR:  relation "nonexistent_table" does not exist
LINE 1: SELECT * FROM nonexistent_table;
                      ^
```

"**relation**" is PostgreSQL's formal word for *table-like thing* — a table, a
view, a materialized view. When an error says "relation does not exist", read it
as "table does not exist".

🎯 **Interview** — "What's the difference between a relation and a table in
Postgres?" A table is one kind of relation. Views, materialized views, indexes
and sequences are also relations. They all live in the catalog table
`pg_class`. You will meet `pg_class` properly on Day 73.

---

## Part 7 — Two habits to set up now

### 1. Command history

`psql` remembers everything you type, across sessions, in `~/.psql_history`.
Press **↑** to walk backwards through it. Press **Ctrl-R** to search it.

▶ **Try it** — press ↑ a few times. Everything you've typed today is there.

This is why you should not be afraid of long queries: you never retype them,
you recall and edit them.

### 2. A config file

Create `~/.psqlrc` with these lines:

```
\set QUIET 1
\timing on
\pset null '␀'
\set COMP_KEYWORD_CASE upper
\set HISTSIZE 10000
\unset QUIET
```

Every `psql` session now starts with timing on and NULLs visible. That second
one will save you real confusion on Day 9.

💡 **Note** — Tab completion works in `psql`. Type `SEL` then Tab. Type
`\d` then Tab. Use it constantly.

---

## Traps & Gotchas

| # | Trap | Why it bites |
|---|---|---|
| 1 | Forgetting the `;` | The prompt changes to `-#` and nothing happens. It is not frozen. |
| 2 | Putting a `;` after a meta-command | `\dt;` fails. Meta-commands take no semicolon. |
| 3 | Assuming `\dt` returning nothing is an error | It means "no tables", which is often correct. |
| 4 | Installing the client but not starting the server | `psql --version` works, connecting fails. Two different things. |
| 5 | Connecting to the wrong database | Always check `\conninfo` when something is "missing". |
| 6 | Losing the `postgres` password on Windows | There is no recovery without editing `pg_hba.conf`. Write it down. |
| 7 | Thinking `postgres` the database is special | It isn't. It's just a default landing spot. |

---

## Interview angles

- **Junior** — "How do you connect to a PostgreSQL database from the command
  line?" → `psql -h host -p 5432 -U user -d database`
- **Junior** — "What's the default PostgreSQL port?" → 5432
- **Mid** — "What's the difference between a database, a schema, and a table?"
  → Server contains databases; databases contain schemas; schemas contain
  tables. Cross-database queries need extra machinery (`postgres_fdw`,
  Day 103); cross-schema queries are trivial.
- **Mid** — "What are `template0` and `template1` for?" → `template1` is the
  default source for `CREATE DATABASE`; `template0` is the pristine copy used
  when you need a guaranteed-unmodified base, e.g. a different encoding.
- **Senior** — "Walk me through what happens when a client connects." → The
  postmaster accepts the TCP connection, authenticates per `pg_hba.conf`, and
  forks a dedicated backend process for that connection. This
  process-per-connection model is exactly why connection pooling matters —
  Day 99.

---

## Practice

> Today's practice is almost all `psql` navigation. That is deliberate: these
> motions need to be automatic before the SQL starts on Day 2.

### Section A — Drill (new concept only)

1. Connect to your server with `psql`.
2. Display your connection info. Which database, user, port and socket?
3. List all databases. How many are there and what are they called?
4. Connect to the `template1` database. What changed about the prompt?
5. Connect back to `postgres`.
6. List all tables in the current database. What does the output say and why?
7. List all roles on the server.
8. Turn on query timing.
9. Turn on expanded display, then turn it off again.
10. Get `psql` help on the SQL command `CREATE DATABASE`.
11. Get the list of all `psql` meta-commands.
12. Run `SELECT 'my first query';`
13. Run `SELECT 2 + 2;` — what is the column called?
14. Run `SELECT version();` — what version and what platform?
15. Run `SELECT current_date;`
16. Run `SELECT current_user;`
17. Run a statement, then use ↑ to recall and re-run it.
18. Quit `psql` and reconnect. Press ↑ — is your history still there?

### Section B — Combination

> On Day 1 there is nothing yet to combine, so Section B asks you to *reason*
> rather than recall.

19. Start typing `SELECT 'abc'` and press Enter without a semicolon. What is the
    prompt now? Get back to a normal prompt two different ways.
20. Type `SELECT 'unclosed` and press Enter. What prompt do you get? Explain it,
    then escape.
21. Run `SELECT 5 / 2;`. The answer is not 2.5. Write down what you think is
    happening. (You'll get the real explanation on Day 14 — but make a guess
    now and write it in `mistakes.md`.)
22. Without looking it up: if a server holds 3 databases and each has 4 tables,
    how many tables can a single `\dt` show you? Explain.

### Section C — Recall

> Nothing to recall yet. From Day 2 onwards this section always has content.
> Instead, do the setup work that the rest of the program depends on:

23. Create the file `mistakes.md` in the root of this program directory. Put one
    line in it today: a thing you got wrong or were surprised by.
24. Create `~/.psqlrc` with the settings from Part 7.
25. Bookmark `https://www.postgresql.org/docs/current/app-psql.html`.
26. Read the "Meta-Commands" section of that page for five minutes. You will not
    remember it. Read it anyway — you are building a map of where things live.

### Section D — Challenge

27. Find out, using only `psql`, what directory your server stores its data in.
    (Hint: there is a setting called `data_directory`, and `SHOW` displays
    settings.)
28. Find out how many connections your server will accept before refusing new
    ones. (Hint: the setting is called `max_connections`.)
29. Work out how to run a single SQL statement from your operating-system shell
    without entering the `psql` prompt at all. (Hint: `psql --help`, look for
    `-c`.)
30. Work out how to make `psql` output a query result as CSV. (Hint: `psql
    --help`, look for `--csv`.)

---

## Solutions

**1.** `psql -U postgres` (macOS/Windows) or `sudo -u postgres psql` (Linux).

**2.** `\conninfo` →
`You are connected to database "postgres" as user "postgres" via socket in "/tmp" at port "5432".`

**3.** `\l` → three: `postgres`, `template0`, `template1`.

**4.** `\c template1` → prompt becomes `template1=#`. The prompt always names the
current database. This is your first line of defence against "my table is
missing" confusion — you are usually in the wrong database.

**5.** `\c postgres`

**6.** `\dt` → `Did not find any relations.` The database contains no tables. Not
an error.

**7.** `\du` → at minimum the `postgres` superuser role.

**8.** `\timing` → `Timing is on.`

**9.** `\x` → `Expanded display is on.` `\x` again → off. Expanded display prints
each column on its own line, which is how you read wide rows. You will use it
constantly from Day 3.

**10.** `\h CREATE DATABASE` — prints the full syntax summary and a doc link.
`\h` with no argument lists every SQL command `psql` knows.

**11.** `\?`

**12.** `SELECT 'my first query';` → one row, column named `?column?`.

**13.** `SELECT 2 + 2;` → `4`, in a column named `?column?`. PostgreSQL only
auto-names a column when it can — a bare expression gets the placeholder.

**14.** `SELECT version();` → something like
`PostgreSQL 16.13 on aarch64-apple-darwin23.6.0, compiled by Apple clang 16.0.0, 64-bit`.
The column is named `version` because the value came from a function, and
PostgreSQL names the column after the function.

**15.** `SELECT current_date;` → today's date, column named `current_date`.

**16.** `SELECT current_user;` → `postgres`, or whichever role you connected as.

**17.** Press ↑. This is the single most-used key in `psql`.

**18.** Yes. History is persisted to `~/.psql_history` on exit.

**19.** The prompt becomes `postgres-#`. Two escapes: type `;` and Enter to run
it, or press `Ctrl-C` to abandon the line.

**20.** The prompt becomes `postgres'#`. The `'` tells you there is an open
single quote — PostgreSQL is treating everything you type as part of a string
literal. Type `'` and `;` to complete it, or `Ctrl-C` to abandon.

**21.** `SELECT 5 / 2;` returns `2`. Both operands are integers, so PostgreSQL
does **integer division** and truncates toward zero. It does not round — `7 / 2`
is `3`, not `4`. Full treatment on Day 14, including the one-character fix.
This catches every beginner exactly once. Write it in `mistakes.md`.

**22.** Four. `\dt` only ever shows tables in the database you are currently
connected to (and, more precisely, only in the schemas on your `search_path`).
There is no way to list tables across databases in one command; a connection
belongs to exactly one database. This is a genuine architectural property of
PostgreSQL and it surprises people coming from MySQL, where `USE db` switches
freely within one connection.

**23–26.** Setup. No answer to check — but do them. Rule L6 exists because the
learners who keep `mistakes.md` finish this program and the ones who don't
mostly don't.

**27.**
```sql
SHOW data_directory;
```
On macOS/Homebrew: `/opt/homebrew/var/postgresql@16`.
On Ubuntu: `/var/lib/postgresql/16/main`.
`SHOW` displays any server setting. `SHOW ALL;` displays every one of them —
run that once, today, just to see how many knobs exist. (There are around 350.
You will meet the twelve that matter on Day 98.)

**28.**
```sql
SHOW max_connections;
```
Usually `100`. That number is far smaller than people expect, and it is the
reason connection pooling exists — Day 99.

**29.**
```bash
psql -U postgres -c "SELECT version();"
```
`-c` runs one command and exits. Enormously useful in scripts and CI.

**30.**
```bash
psql -U postgres --csv -c "SELECT current_date, current_user;"
```
Or from inside `psql`: `\pset format csv`. You will use this to feed query
output into other tools.

---

## Day 01 Checklist

Tick only what is genuinely true.

- [ ] PostgreSQL 14+ is installed and the server is running
- [ ] I can connect with `psql` without looking up the command
- [ ] I know what `=#`, `-#`, `'#` and `(#` mean at the prompt
- [ ] I can use `\l`, `\c`, `\dt`, `\d`, `\du`, `\conninfo`, `\x`, `\timing`, `\q`
- [ ] I know a meta-command starts with `\` and takes no semicolon
- [ ] I ran a statement that errored and I read the caret `^`
- [ ] I know the difference between a server, a database and a schema
- [ ] I have created `mistakes.md` and written one line in it
- [ ] I have created `~/.psqlrc`

If any box is unticked, fix it before Day 2. Today is the cheapest day to be
thorough.

---

## What's next

**Day 02 — The Relational Model & `SELECT`.** You will learn what a table
actually is, and you will write real `SELECT` statements — without any table at
all. That sounds odd. It is the cleanest possible way to learn what a `SELECT`
does before adding the complication of where the data comes from.
