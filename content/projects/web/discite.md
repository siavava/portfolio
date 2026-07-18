---
title: "Discite"
date: 2023-12-04
tag: "design / web"
repo: "https://github.com/lostflux/discite-frontend"
url: "https://discite-website.vercel.app/"
featured: true
tech:
  - "Swift"
  - "TypeScript"
  - "Node"
  - "MongoDB"
  - "Python"
summary: "Discite turns idle screen time into learning — a short-form video app that teaches computer science fundamentals through bite-sized, swipeable clips, spanning a SwiftUI client, an Express API, an ML clipping pipeline, and a vector recommendation engine."
---

**Discite** turns idle screen time into learning: a short-form video app that
teaches computer science fundamentals through bite-sized, swipeable clips.
_Discite optimizes learning for the modern attention span._ Built as my
Dartmouth [CS98 senior capstone][article], it is a five-part platform — a
SwiftUI [iOS client][frontend], a TypeScript / Express [API][backend] on
MongoDB, a Python [ML service][ml] that cuts long lectures into clips, a
[recommendation engine][recs] over a vector index, and an AWS streaming tier.

$$
% caption: End to end, the SwiftUI client speaks only to the Express API, which
% persists state in MongoDB and queries a Pinecone vector index for related
% clips. The ML service cuts lectures into clips and registers their
% metadata with the API; the recommendation engine ranks candidates; S3 and
% CloudFront stream the signed HLS bytes back to the app.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  bx/.style={rectangle, draw=acc, fill=acc!8, minimum width=2.7cm, minimum height=0.95cm, inner sep=3pt, align=center},
  lbl/.style={font=\scriptsize\ttfamily, text=acc}]
  \definecolor{acc}{HTML}{2348F2}
  \node[bx] (app) at (0, 0) {iOS app\\SwiftUI};
  \node[bx] (cdn) at (0, 2.1) {S3 + CloudFront};
  \node[bx] (api) at (4.3, 0) {Express API\\Node};
  \node[bx] (mongo) at (4.3, -2.3) {MongoDB};
  \node[bx] (ml) at (8.6, 2.1) {ML service\\CLIP + BART};
  \node[bx] (pine) at (8.6, 0) {Pinecone\\+ Algolia};
  \node[bx] (recs) at (8.6, -2.3) {recommendation\\engine};
  \draw[<->, black!55] (app) -- (api) node[midway, above, lbl]{REST / JWT};
  \draw[->, black!55] (cdn) -- (app) node[midway, left, lbl]{HLS};
  \draw[->, black!55] (api) -- (cdn) node[midway, above right, lbl]{sign .m3u8};
  \draw[<->, black!55] (api) -- (mongo) node[midway, right, lbl]{Mongoose};
  \draw[->, black!55] (api) -- (pine) node[midway, above, lbl]{vector query};
  \draw[->, black!55] (recs) -- (pine) node[midway, right, lbl]{rank / upsert};
  \draw[->, black!55] (ml) -- (api) node[midway, above right, lbl]{PUT /videos};
\end{tikzpicture}
$$

**The iOS client.** [The app][frontend] is SwiftUI, organized MVVM with a
`Views` / `ViewModels` / `Models` / `Service` split per feature.
`Authentication` obtains a JWT and stores it in the Keychain (`KeychainItem`),
with a Google sign-in path alongside email. `Watch` is the core surface: an
IGList-backed feed (`PlayerView`, `EmbeddedVideoCell`, `NavigationDotsView`)
where a `SwipeDirection` enum reads the drag gesture, sideways swipes stepping
through a topic's clips and a downward swipe advancing to the next topic, all
over a `CustomVideoPlayer`. `Explore` drives topics, playlists, and search;
`Account` holds profiles and a `Friends` graph. The client keeps no business
logic; it is a consumer of the REST API.

**The API and data model.** [The backend][backend] follows Express's
model–controller–router layout in TypeScript, with Passport guarding routes by
JWT (`requireAuth`, `requireSignin`, `requireAdmin`). Mongoose maps a small set
of collections:

`user`
: names, lowercase-unique email and username, bcrypt password, `savedPlaylists`, `isAdmin`, email verification

`video_metadata`
: `title`, `youtubeURL`, `topicId[]`, `clips[]`, `views` / `likes` / `dislikes` sets, `isVectorized`, `isClipped`

`clip_metadata`
: `videoId`, `duration`, `thumbnailURL`, `clipURL` pointing at a CDN manifest, and the same engagement sets

`user_affinity`
: per-topic `affinities` and `complexities` maps in `[0, 1]`, plus a bounded `activeAffinities` buffer of recent watches

Routes cover auth (`/auth/signup`, `/auth/signin`), the social graph
(`/relationships`, `/connections/:userId`), engagement (`GET /videos/:videoId`,
nested comment threads, and `like` / `dislike` / `toohard` / `tooeasy`, each of
which nudges the caller's affinity), and recommendations. Around fifty Cypress
specs exercise it end to end (`affinity`, `recommendation`, `vectorized-rec`,
`watch-history`, `search`, `user`, `video`).

**Turning lectures into clips.** [The ML service][ml] is a Dockerized FastAPI
app. Its `/split` route runs `process_video`, pulling a YouTube video's frames
and transcript, then labels both against a topic set: **CLIP**
(`clip-vit-base-patch32`) scores each frame and **BART** (`bart-large-mnli`)
does zero-shot classification on the transcript around each second. That yields
a per-second topic time-series, which a `tfidf` pass reweights so keywords
common to the whole video (`SELECT` throughout a SQL lecture) count for less
than distinctive ones. A sliding-window change detector then compares each
window's topic mixture against a running mean or median; when the gap crosses a
threshold it marks a clip boundary. Raw segments go to S3 and their metadata is
`PUT` to the API.

**Choosing what to play.** [The engine][recs] is a separate FastAPI service over
a Pinecone cosine index (namespace `video-transcripts`) and an Algolia search
index. Candidate generation queries Pinecone for videos near a seed clip;
ranking then reorders them by taste, as `VideoRanker` adds each viewer's
per-topic affinity to the similarity score and re-sorts. The backend also
queries Pinecone directly for its `vectorized` feed. Two signals from the
affinity model, interest and difficulty, together with vector-space topic
similarity, decide the next clip, and every like, dislike, `toohard`, or
`tooeasy` event feeds back into the scores so the sequence adapts as you learn.

**Streaming and infrastructure.** Clips never stream from the database. Bytes
live on Amazon S3 and reach the app over HLS through CloudFront. When the client
wants a clip it asks the API for a signed `.m3u8`; a Lambda fetches and caches
the CloudFront private key, checks that the request is authorized, and signs the
manifest, appending signed params to every `.ts` segment so playback loads
progressively. The public docs and marketing site is a separate Nuxt Content
app.

Read more in the [Medium write-up][article] and the project's
[architecture docs][docs].

[article]:  https://medium.com/dartmouth-cs98/upgrade-your-screen-time-learn-cs-fundamentals-with-discite-14c3337cb074
[docs]:     https://discite-website.vercel.app/docs/architecture
[frontend]: https://github.com/lostflux/discite-frontend
[backend]:  https://github.com/lostflux/discite-backend
[ml]:       https://github.com/lostflux/discite-ml
[recs]:     https://github.com/lostflux/discite-recs
