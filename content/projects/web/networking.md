---
title: "Networking Platform"
date: 2023-06-03
tag: "design / web"
repo: "https://github.com/lostflux/networking-platform"
url: "https://net.amittai.studio"
featured: false
tech:
  - "React"
  - "Redux"
  - "MongoDB"
  - "Sass"
summary: |-
  goloco, a networking tool that keeps companies, contacts, tasks, and call
  notes in one workspace, with a five-slice Redux store over a
  token-authenticated Express/Mongoose API and Gmail integration.
---

**goloco** is a networking tool for the job hunt. It keeps the companies
you are targeting, the people you know at each, the tasks that chase them
down, and the notes from every call in one workspace, instead of scattered
across spreadsheets and shared folders. Built with
[React][reactjs],
[TypeScript][typescriptlang], and
[Redux][redux], bundled with [Vite][vitejs],
talking to a separate Express/Mongoose API backed by
[MongoDB][mongodb] Atlas.

$$
% caption: Inside the goloco client, five Redux slices feed thunked axios
% caption: calls, carrying a bearer token, to a separate Express/Mongoose
% caption: API that persists to MongoDB and reads contact email history from
% caption: Gmail.
\begin{tikzpicture}[
    font=\small,
    box/.style={draw=acc, fill=acc!8, align=center, inner sep=6pt, minimum height=1cm},
    flow/.style={->, >=stealth, draw=black!50, thick},
    lbl/.style={font=\scriptsize\ttfamily, text=acc}
  ]
  \definecolor{acc}{HTML}{2348F2}
  \node[box] (client) at (0,0) {React client\\views + modals};
  \node[box] (store) at (0,-2.4) {Redux store\\user / company / person\\task / note};
  \node[box] (api) at (5.6,-1.2) {goloco API\\Express + Mongoose};
  \node[box] (db) at (10.2,-1.2) {MongoDB\\Atlas};
  \node[box] (gmail) at (5.6,-3.9) {Gmail API};

  \draw[flow] (client) -- (store) node[midway, right, lbl] {dispatch};
  \draw[flow] (store.east) -- (api.west) node[midway, above, lbl] {axios + token};
  \draw[flow] (api.east) -- (db.west) node[midway, above, lbl] {mongoose};
  \draw[flow] (gmail.north) -- (api.south) node[midway, right, lbl] {/api/emails};
\end{tikzpicture}
$$

One store holds five slices. The Redux root in `store/reducers` combines
five reducers: `user`, `company`, `person`, `task`, and `note`. Each holds
the authoritative client copy of one entity, written through
[Immer][immer] so a handler mutates a draft and
Redux hands back fresh state. A company, the people at it, and the tasks
and notes attached to either are read from whichever view needs them, a
profile page, a list, or a modal, without threading data through props.

Every action in `store/actions` is an async thunk over [axios][axios-http],
each carrying a bearer token. Sign-in posts to
`/api/signin`; the token that comes back is kept in `localStorage` and
attached as the `authorization` header on every later request, and
`user_reducer` flips `authenticated` once the profile returns. The entity
thunks map onto the API directly: `/api/companies`, `/api/people`,
`/api/tasks`, `/api/notes`, each with create, get-one, list, update,
delete, and a `find?q=` search. Tasks and notes are also fetched by
association, so a company profile can pull every note tied to it.

Contacts carry their own email history. The person and company views
call `/api/emails?person=` and `?company=`, and the API reads Gmail through
the Google APIs client, so a contact's recent correspondence sits beside
the call notes on them.

On the interface itself, [react-md-editor][react-md]
handles note bodies, `react-select` and `react-datepicker` sit in the
create-task and create-person modals, and `react-window` keeps long people
and company lists cheap to render, all styled with Bootstrap and Sass.

Built as a collaborative project with
[Bansharee Ireen][bansharee-ireen],
[Yizhen Zhen][yizhen-zhen],
[Cindy Li Wang][cindylwang], and
[Johan Cruz Hernandez][johan-cruz].

[reactjs]:         https://reactjs.org
[typescriptlang]:  https://www.typescriptlang.org
[redux]:           https://redux.js.org
[vitejs]:          https://vitejs.dev
[mongodb]:         https://www.mongodb.com
[immer]:           https://immerjs.github.io/immer/
[axios-http]:      https://axios-http.com
[react-md]:        https://uiwjs.github.io/react-md-editor/
[bansharee-ireen]: https://www.linkedin.com/in/bansharee-ireen-184712274/
[yizhen-zhen]:     https://www.linkedin.com/in/yizhen-zhen/
[cindylwang]:      https://www.linkedin.com/in/cindylwang/
[johan-cruz]:      https://www.linkedin.com/in/johan-cruz-hernandez-2204b9183/
