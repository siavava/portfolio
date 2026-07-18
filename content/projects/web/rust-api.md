---
title: "Rust API"
date: 2023-10-09
tag: "design / web"
repo: "https://github.com/entendr/demo-rs-api"
featured: false
tech:
  - "Rust"
  - "Rocket"
  - "MongoDB"
summary: "A proof-of-concept REST API in Rust with the Rocket framework and a MongoDB backend, trading Express familiarity for compile-time memory safety."
---

A REST API written in [Rust][rust-lang] with the
[Rocket][rocket] framework and a [MongoDB][mongodb]
backend. Building the same service in [TypeScript][typescriptlang]
on [Express][expressjs] is routine; this was a proof-of-concept for a
larger project, testing whether Rust's guarantees carry into everyday web
plumbing.

**Why Rust for a web service.** Rust offers C-like performance without a garbage
collector, and its borrow checker rules out use-after-free and data races at
compile time rather than at runtime. For an API expected to stay up under
concurrent load, that moves a class of failures from production to the build.

**One model, four routes.** The service is a small events API. A single `Event`
struct in `events.rs` carries a `name`, `description`, a BSON `time`, a
`location`, and a `Vec<String>` of `participants`, plus an optional `_id` that
serde skips when it is absent — so a client can `PUT` an event without inventing
an id, and Mongo mints the `ObjectId` on insert. `main.rs` mounts exactly four
handlers: `GET /` (a health check), `GET /events` and `GET /events/<id>` to read
all events or one by id, and `PUT /events` to insert one. It is create-and-read,
not full CRUD.

**Rocket handles the request lifecycle.** Routes are ordinary async functions
annotated with a method and path. Rocket parses the path and the JSON body into
typed arguments before the handler runs, so a `PUT` whose body does not
deserialize into an `Event` is rejected before any logic executes. The Mongo
client connects once at startup — `Database::init` reads `MONGODB_URI` from the
environment and opens a handle to the `events` collection — and that `Database`
lives in Rocket's managed state, so every handler borrows the same shared handle
through a `&State<Database>` argument instead of opening its own.

$$
% caption: Rocket deserializes the JSON body into a typed Event, hands each route the
% one Database it holds in managed state, and the driver reads and writes
% BSON in a single events collection.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  bx/.style={rectangle, draw=acc, fill=acc!8, minimum width=2.5cm, minimum height=0.95cm, inner sep=3pt, align=center}]
  \definecolor{acc}{HTML}{2348F2}
  \node (cl) at (0, 0) {client};
  \node[bx] (rk) at (3, 0) {Rocket\\routes};
  \node[bx] (db) at (6.6, 0) {Database\\managed state};
  \node[bx] (mg) at (10.2, 0) {MongoDB\\events};
  \draw[->, black!55] (cl) -- (rk) node[midway, above, font=\scriptsize\ttfamily, text=acc]{JSON};
  \draw[->, black!55] (rk) -- (db) node[midway, above, font=\scriptsize\ttfamily, text=acc]{State};
  \draw[->, black!55] (db) -- (mg) node[midway, above, font=\scriptsize\ttfamily, text=acc]{BSON};
  \node[align=left, font=\scriptsize\ttfamily, text=acc, anchor=north] at (3, -0.95)
    {GET /events\\GET /events/<id>\\PUT /events};
\end{tikzpicture}
$$

**Serde bridges three type systems.** A document crosses three representations —
JSON on the wire, BSON in the database, and a Rust struct in the handler — and
serde derives the serialization and deserialization between them straight from
the struct definition. The friction is front-loaded: getting the types and
lifetimes to line up across async handlers is the work, after which the compiler
guarantees the wiring is sound. Two small macros round it off — `db!` builds and
unwraps the connection at launch, and `event!` constructs an `Event` from its
fields.

This service backs the live comment features on
[my blog][amittai] and
[my reference notes][notes] — open any article
and leave a note to see it at work.

[rust-lang]:      https://www.rust-lang.org
[rocket]:         https://rocket.rs
[mongodb]:        https://www.mongodb.com
[typescriptlang]: https://www.typescriptlang.org
[expressjs]:      https://expressjs.com
[amittai]:        https://amittai.space
[notes]:          https://notes.amittai.studio
