---
title: "Blog"
date: 2023-08-21
tag: "design / web"
repo: "https://github.com/siavava/blog"
url: "https://amittai.space"
featured: false
tech:
  - "Nuxt"
  - "TypeScript"
  - "Sass"
summary: "A ground-up redesign of my personal blog — statically generated with Nuxt and SCSS, deployed on Netlify at amittai.space, over a live layer of comments, inline highlights, a Spotify-fed dynamic island, and view counts served by a Rust WebSocket API."
---

A ground-up redesign of my personal blog, and a new domain to go with it,
[amittai.space][amittai]. Built with [Nuxt][nuxt] 4
(Vue) and [Sass][sass-lang] on [Bun][bun], statically
generated and deployed on [Netlify][netlify].

**The content is a compiled pipeline, not a folder of HTML.** Posts are
Markdown in a [Nuxt Content][content] collection; build-time
hooks rewrite each file before parsing (display-math `tikzpicture` blocks
become fenced `tikz`, Markdown quotes become typographic ones), then every
TikZ block is rendered to SVG with
[node-tikzjax][node-tikzjax], math runs through
`rehype-katex` against a custom macro layer, and code is highlighted by
[Shiki][shiki]. Parsed pages land in a
[SQLite][sqlite] store (`better-sqlite3`), each keeping its
post-transform `rawbody`; `nuxi generate` then crawls the link graph and
freezes the site to static files, prerendering RSS, Atom, and JSON feeds, a
sitemap, an `llms.txt`, and a `/raw/*.md` route off the same store.

**A live layer sits on the static pages.** The browser opens one WebSocket,
once, via a `useSocket` singleton to a companion Rust service
([Actix-Web][actix] + [MongoDB][mongodb]) at
`api.amittai.studio/connect`. Every frame is tagged with a `scope`, and each
store subscribes only to the scopes it cares about; the connection queues
messages while offline and reconnects on its own. Four features ride it.

## Comments

Comments are written in a [TipTap][tiptap] editor that emits two
fields, `text` (plain) and `markup` (pre-rendered HTML). A new comment goes up
as a `comments`-scope `create` frame. The service parses the scope, writes a
`BlogComment` into MongoDB's `comments` collection — stamping `created_time`,
zeroing `likes`, and, for a reply, pushing the new id into the parent's
`replies` array — then publishes a `CommentEvent` on a
[Tokio][tokio] broadcast channel. The socket forwards that event to
a peer only when the peer's _active path_ matches the comment's page; that path
is set by a separate `watch` frame and is the same filter that gates live view
counts. Replies are stored flat (each document keeps a `reply_to` pointer and a
`replies` id list) and reassembled into a nested tree in memory on read.
Private notes are comments with `is_private` set: the list query returns public
comments plus the caller's own private ones.

$$
% caption: A comment — and a highlight, which is just a comment carrying a text
% caption: anchor — travels clockwise: up the single WebSocket as a scoped frame,
% caption: through the scope router into the comments collection, and back out on
% caption: a Tokio broadcast channel. The socket forwards the event only to peers
% caption: whose watched path matches the comment's page.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  st/.style={rectangle, draw=acc, fill=acc!8, minimum width=2.7cm, minimum height=0.72cm, inner sep=3pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[st] (br)   at (0, 2.4) {browser};
  \node[st] (conn) at (4.2, 2.4) {/api/connect};
  \node[st] (rt)   at (8.4, 2.4) {scope router};
  \node[st] (coll) at (8.4, 0) {comments coll};
  \node[st] (bc)   at (4.2, 0) {broadcast};
  \draw[->, black!55] (br) -- node[above, font=\scriptsize\ttfamily, text=acc] {WebSocket} (conn);
  \draw[->, black!55] (conn) -- node[above, font=\scriptsize\ttfamily, text=acc] {create} (rt);
  \draw[->, black!55] (rt) -- node[right, font=\scriptsize\ttfamily, text=acc] {persist} (coll);
  \draw[->, black!55] (coll) -- node[above, font=\scriptsize\ttfamily, text=acc] {CommentEvent} (bc);
  \draw[->, black!55] (bc.west) -| node[above, pos=0.25, font=\scriptsize\ttfamily, text=acc] {watched path} (br.south);
\end{tikzpicture}
$$

## Inline highlights

A highlight is a comment, not a separate record. When you select text, the
anchor is serialized into the comment's `markup` string as `scope:index|quoted
text` followed by an occurrence index and the words on either side, joined by
ASCII unit separators. No DOM offsets are stored, so the anchor survives a
re-render. On load, `applyHighlights` groups the page's comments by `markup`,
normalizes the article's text, and searches for each quote inside
`.content-container`; when a quote appears more than once it disambiguates
first by the saved context words, then by the occurrence index, and wraps the
matched range in a `<mark>` with a margin annotation. Because highlights are
comments, they arrive over the same socket and light up live for everyone on
the same page. A highlight can also be shared as a link: `shareMarkup` packs
the anchor into a `?hl=...&by=...` query, and the recipient's page finds the
text and marks it green with the sharer's name on hover.

## Now playing

The dynamic island carries two independent things. Owner-published status
slots — `watching`, `reading`, `working_on`, `status` — live in the `now`
scope: each edit is written to a MongoDB `now` collection with a TTL on
`expires_at`, and the write broadcasts a `NowEvent` to _every_ connected
client, so all islands update at once. Music is separate. The `playback` scope
is request-and-reply, on demand: when the page asks for the current track, the
service spawns a task that calls the Spotify Web API through `SpotifyClient`.
That client holds an OAuth token, refreshing it against `accounts.spotify.com`
with a stored refresh token, then hits `me/player/currently-playing`; a `204`
(nothing playing) falls back to the most recent track from `recently-played`.
Spotify dropped `preview_url` from that response, so the client scrapes each
track's `/embed/` page for the `audioPreview` URL. Nothing is polled
server-side and there are no webhooks; the reply returns only to the client
that asked.

$$
% caption: The island runs two scopes side by side. The playback branch is
% caption: request-and-reply: a spawned task calls the Spotify Web API
% caption: through SpotifyClient (refreshing its OAuth token on the way),
% caption: and the track comes back only to the client that asked. The now
% caption: branch is broadcast: owner status slots persist to a TTL
% caption: collection and the NowEvent fans out to every connected client at
% caption: once.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  st/.style={rectangle, draw=acc, fill=acc!8, minimum width=2.7cm, minimum height=0.72cm, inner sep=3pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[st] (br)   at (0, 1.6) {browser};
  \node[st] (conn) at (4.2, 1.6) {/api/connect};
  \node[st] (spot) at (8.4, 3.0) {SpotifyClient};
  \node[st] (api)  at (12.2, 3.0) {Spotify API};
  \node[st] (now)  at (8.4, 0.2) {now coll (TTL)};
  \draw[->, black!55] (br) -- node[above, font=\scriptsize\ttfamily, text=acc] {WebSocket} (conn);
  \draw[->, black!55] (conn.north) |- node[above, pos=0.75, font=\scriptsize\ttfamily, text=acc] {playback: ask} (spot.west);
  \draw[<->, black!55] (spot) -- node[above, font=\scriptsize\ttfamily, text=acc] {OAuth} (api);
  \draw[->, black!55] (spot.south) |- node[below, pos=0.6, font=\scriptsize\ttfamily, text=acc] {track: to asker only} (conn.east);
  \draw[->, black!55] (conn.south) |- node[below, pos=0.7, font=\scriptsize\ttfamily, text=acc] {now: set/get} (now.west);
  \draw[->, black!55] (now.south) -| node[above, pos=0.6, font=\scriptsize\ttfamily, text=acc] {NowEvent: to every client} (br.south);
\end{tikzpicture}
$$

## View counts

View counts are never requested directly. When a client's `watch` path
changes, the service atomically increments that route's document in the `views`
collection and broadcasts the new total; a client sees the update only for the
page it is on, with the archive view the one exception, which receives every
route's count. A second counter tracks presence: an atomic client tally moves
on each connect and disconnect and is broadcast to all sockets as a live
reader count. A REST-plus-SSE `/views/` route, backed by a MongoDB change
stream with a heartbeat, mirrors the same data for consumers that are not on
the socket.

**One design system, two moods.** The visual language follows
[minimalism][minimalism]: a restrained type scale, generous
whitespace, few colors. Type, color, and spacing rules live in shared Sass
partials rather than per-component scopes, so a single change propagates
everywhere; a light and dark color mode and a stricter "Rams mode" toggle
(applied before first paint to avoid a flash) sit on top. The move to
`amittai.space` was the occasion to retire the old design entirely rather
than patch it, so nothing carried over except the writing.

[amittai]:      https://amittai.space
[nuxt]:         https://nuxt.com
[sass-lang]:    https://sass-lang.com
[bun]:          https://bun.sh
[netlify]:      https://netlify.com
[content]:      https://content.nuxt.com
[node-tikzjax]: https://github.com/prinsss/node-tikzjax
[shiki]:        https://shiki.style
[sqlite]:       https://www.sqlite.org
[actix]:        https://actix.rs
[mongodb]:      https://www.mongodb.com
[tiptap]:       https://tiptap.dev
[tokio]:        https://tokio.rs
[minimalism]:   https://minimalism.com
