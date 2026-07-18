---
title: "Kahoots API"
date: 2023-05-04
tag: "design / web"
repo: "https://github.com/lostflux/kahoots-api.amitt.ai"
url: "https://kahoots-api.amittai.studio"
featured: false
tech:
  - "TypeScript"
  - "Express"
  - "Node"
summary: "An HTTP API for Kahoot-style quiz games — quizzes, live sessions, and time-weighted scoring, built on TypeScript, Express, and MongoDB."
---

An HTTP API for running [Kahoot][kahoot]-style quiz games: a
host builds a quiz, players join a live session with a game code, and
everyone answers the same timed multiple-choice questions. Built with
[TypeScript][typescriptlang],
[Express][expressjs], and [Node][nodejs], with
quizzes and game state persisted in [MongoDB][mongodb].

**Resources over HTTP.** The API is organized around three resources.
A **quiz** is an ordered list of questions, each with its choices and the
index of the correct one. A **game** is a session created from a quiz,
identified by a join code. A **player** belongs to a game and accumulates
a running score. Express routers expose create, read, update, and delete
over each, and Mongo stores them as documents so a session survives
between requests rather than living in process memory.

**Time-weighted scoring.** A correct answer earns points scaled by how
quickly it arrives inside the question's time limit; a wrong answer earns
nothing. With response time $t$ and question limit $T$, the standard rule
awards

$$
\operatorname{score} = \left(1 - \tfrac{1}{2}\,\tfrac{t}{T}\right) P_{\max}
$$

for a correct answer and $0$ otherwise, so an instant answer is worth the
full $P_{\max}$ and one at the buzzer is worth half. The server times each
question from when it is served, which keeps scoring authoritative on the
backend rather than trusting a client-reported clock.

**Game flow.** A session moves through a lobby while players join, then
one question phase per question, then a results phase that reveals the
answer and the updated standings. The server holds the current phase and
advances it, so every client reads the same state from one source.

[kahoot]:         https://kahoot.com
[typescriptlang]: https://www.typescriptlang.org
[expressjs]:      https://expressjs.com
[nodejs]:         https://nodejs.org
[mongodb]:        https://www.mongodb.com
