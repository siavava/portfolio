---
title: "NoSQL App"
date: 2022-11-03
tag: "systems"
repo: "https://github.com/lostflux/nosql"
featured: false
tech:
  - "Python"
  - "MongoDB"
  - "NoSQL"
  - "Database Systems"
summary: |-
  A blog server on a MongoDB document store, driven by a Python client that
  posts, shows, comments on, and deletes threads in a single collection.
references:
  - https://notes.amittai.studio/algorithms/data-structures/b-trees
---

A blog server backed by [MongoDB][mongodb] and driven
by a [Python][python] client. One class,
`MongoBlogServer`, maps four text commands — `post`, `show`, `comment`,
and `delete` — onto operations against a single collection.

Everything lives in database `blog`, collection `posts`, where both posts
and comments are documents in that one collection. A post carries
`blogName`, `userName`, `title`, `postBody`, a `tags`
array, a `timestamp`, a `permalink`, and a `comments` array. The
permalink is derived, not supplied: a post's is its blog name joined to
its title with every non-alphanumeric run replaced by an underscore, and
a comment's is its timestamp. A unique index on `permalink` enforces
that each is distinct, and a second index on `blogName` turns "show this
blog" into a keyed lookup rather than a scan of the collection.

Comments are stored as references rather than embedded. A comment is its
own document in the same `posts` collection; the parent's `comments` array
holds only the permalink strings of its children. A thread is therefore
a tree linked by permalink: `show_posts` finds a blog's posts, then walks
each `comments` array with a `find_one` by permalink, recursing into
nested replies. That is adjacency-by-reference in a store with no joins —
the relationship the application maintains, because MongoDB does not.

Each command is a short sequence of collection operations. `post` inserts
a document; `comment` inserts a comment document and then `$push`es its
permalink into the parent with an `update_one`; `delete` is a soft delete
that `$set`s `postBody` to "deleted by \<user\>" rather than removing the
document, so replies that still reference it stay reachable.

The index behind those keyed lookups is a B-tree — the same balanced tree
relational engines reach for.

Collaborative project with
[Ke Lou][ke-lou].

[mongodb]: https://www.mongodb.com/
[python]:  https://www.python.org/
[ke-lou]:  https://www.linkedin.com/in/ke-lou-898301133
