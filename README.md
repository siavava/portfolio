# Portfolio

> And so it begins.

Personal portfolio — a single page: a radial interests map, a black name bar,
who/now columns, draggable review bubbles, and a dream tracker, with a
timeline that opens out of the name bar. Built with Nuxt 4, Nuxt Content,
Pinia, and VueUse.

## Setup

```bash
bun install
make dev        # local dev server
make generate   # static build
make lint       # eslint --fix
make lint-md    # markdownlint
make typecheck  # nuxi typecheck
```

## Content

Everything editable lives in `content/`:

- `who.md` — bio paragraphs (supports `:chip{…}`, `:bio-target[…]{node="…"}`, and
  `:timeline-target[…]{year="…"}` inline components)
- `timeline/*.md` — the timeline, one file per year
- `now/*.md` — current projects
- `reviews/*.md` — review bubbles. **These are placeholders** — swap in real
  quotes (author, role, and body) before shipping.
- `dreams.yml` — dream-tracker items (`done: true` gets the green double check)
- `interests.yml` — the radial interests map (branches, colors, children)
- `profile.yml` — name, email, socials, footer text

## Timeline

One file per year in `content/timeline/`; each entry is a `::period` block.

```md
---
year: 2023
title: "2023"
---

::period{from="Sep" to="Mar 2024"}
Teaching assistant for Systems (CS 50).

Students write their own data structures in C…
::
```

- `from`: start month (`Sep`, `September`, or `9`). `to`: optional end month,
  with its year when it crosses New Year (`to="Mar 2024"`).
- The first paragraph is the headline.

Linking in:

- `/timeline?year=2024&period=aug`
- `who.md`: `:timeline-target[text]{year="2024" period="Aug"}` (`period` optional)
