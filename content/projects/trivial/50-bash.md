---
title: "Bash Scripting"
date: 2021-04-05
tag: "systems"
repo: "https://github.com/siavava/bash"
featured: false
tech:
  - "Bash"
  - "Regex"
summary: "Shell scripts over a US COVID-19 vaccine dataset: a Markdown report of the states with the most doses, and a source-file summarizer, built from Unix filter pipelines."
---

A set of shell scripts that wrangle a US COVID-19 vaccine dataset,
`vaccine_data_us.csv`, from the command line. Each treats the file as a
stream of comma-separated lines and composes standard Unix filters
through pipes.

`top10.sh` builds a Markdown table of the ten states with the most doses
administered. It keeps the `All`-vaccine-type rows, projects the
`Province_State` and `Doses_admin` columns with `cut -d ,`, sorts them
numerically in descending order, and takes the first ten
(`sed -n '/All/p' | cut -d , -f2,10 | sort -t ',' -k 2 -nr | head -n 10`),
then wraps each field in pipe characters to form the table rows.

`summarize.sh` is a small documentation tool that emits each `.sh`, `.c`,
or `.h` file it is given inside a fenced Markdown code block. It uses
[`sed`][sed] to strip the shebang and the leading header comment, and
selects the language by a [regular expression][regular-expression] match on
the file extension. Between them the two scripts cover involved reporting
tasks without a single hand-written loop over the data.

[sed]:                https://en.wikipedia.org/wiki/Sed
[regular-expression]: https://en.wikipedia.org/wiki/Regular_expression
