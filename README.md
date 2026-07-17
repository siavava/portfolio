# Portfolio

> And so it begins.

Personal portfolio — a single page in the style of [vilinskyy.com](https://www.vilinskyy.com/):
a radial interests map, a black name bar, who/now columns, draggable review
bubbles, and a dream tracker. Built with Nuxt 4, Nuxt Content, Pinia, and VueUse.

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

- `who.md` — bio paragraphs (supports `:chip{…}` and `:bio-target[…]{node="…"}` inline components)
- `now/*.md` — current projects
- `reviews/*.md` — review bubbles. **These are placeholders** — swap in real
  quotes (author, role, and body) before shipping.
- `dreams.yml` — dream-tracker items (`done: true` gets the green double check)
- `interests.yml` — the radial interests map (branches, colors, children)
- `profile.yml` — name, email, socials, footer text
