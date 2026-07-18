---
title: "Dartmouth Robotics Club Website"
date: 2023-08-10
tag: "design / web"
repo: "https://github.com/lostflux/robotics-website"
url: "https://dartmouthrobotics.com"
featured: false
tech:
  - "design"
  - "TypeScript"
  - "Next"
summary: "A redesigned website for the Dartmouth Robotics Club, built with Next.js and SCSS and deployed on Vercel."
---

A redesign of the [Dartmouth Robotics Club][dartmouthrobotics]
website. Built with [Next][nextjs] 13 (App Router, React) and
[SCSS][sass-lang], deployed on [Vercel][vercel].

**One page, composed of sections.** `app/page.tsx` stacks five section
components — `Header`, `Hero`, `Projects`, `Members`, `Footer` — under a
single root layout that sets the Inter font and the "Making Things Move."
metadata. Most of it is static club content: who the team is, what the
projects are, how to join. The `Hero` runs a
[typewriter effect][typewriter-effect] over
that tagline; everything else is plain markup and per-section SCSS
(`hero.scss`, `members.scss`, `projects.scss`, and a shared `colors.scss`
holding the palette).

**A data-driven roster.** `Members` is the one moving part. It fetches
`public/data/members.yml` at runtime, parses it with
[js-yaml][js-yaml], and renders a `MemberCard`
per entry — each member a `name`, `roles`, `categories`, `link`, and
`image`. Filter buttons (All, Leadership, Competitive, Product Design)
narrow the grid by matching against a member's `categories`, so adding or
recategorizing someone is an edit to the YAML file rather than a code
change.

[dartmouthrobotics]: https://dartmouthrobotics.com
[nextjs]:            https://nextjs.org
[sass-lang]:         https://sass-lang.com
[vercel]:            https://vercel.com
[typewriter-effect]: https://www.npmjs.com/package/typewriter-effect
[js-yaml]:           https://github.com/nodeca/js-yaml
