---
title: "Tiny Search Engine"
date: 2021-05-22
tag: "systems"
repo: "https://github.com/lostflux/tse"
featured: true
tech:
  - "C"
  - "Bash"
  - "Make"
  - "Web Crawling"
summary: |-
  A search engine in plain C — a crawler, an indexer, and a querier connected
  by files on disk, with ranked results and boolean query operators.
references:
  - https://notes.amittai.studio/algorithms/graphs/representations-and-traversal
  - https://notes.amittai.studio/algorithms/data-structures/hash-tables
---

A [search engine][web-search]
written in plain C: three small programs — a crawler, an indexer, and a
querier — connected by nothing but files on disk. Each one does a single
job, validates its inputs defensively, and writes an artifact the next
stage reads. They share two libraries: a `common` module (`index`,
`pagedir`, `word`) and `libcs50`, which supplies the generic containers
the pipeline is built on: a `bag`, a `hashtable`, a `set`, a `counters`
set, and a `webpage` fetcher.

$$
% caption: The crawler walks the web graph and saves one file per page; the indexer
% inverts those pages into a word $\to$ (page, count) map; the querier loads
% the index and answers ranked boolean queries.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  st/.style={rectangle, draw=acc, fill=acc!8, minimum width=1.9cm, minimum height=0.8cm, inner sep=2pt},
  ar/.style={rectangle, draw=black!55, dashed, minimum width=1.6cm, minimum height=0.65cm, inner sep=2pt, font=\scriptsize, fill=black!8}]
  \definecolor{acc}{HTML}{2348F2}
  \node[st] (crawler) at (0, 0) {crawler};
  \node[ar] (pages) at (2.6, 0) {page f\/iles};
  \node[st] (indexer) at (5.2, 0) {indexer};
  \node[ar] (index) at (7.8, 0) {index f\/ile};
  \node[st] (querier) at (10.4, 0) {querier};
  \draw[->] (crawler) -- (pages);
  \draw[->] (pages) -- (indexer);
  \draw[->] (indexer) -- (index);
  \draw[->] (index) -- (querier);
  \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (0, -0.65) {walks the web};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (5.2, -0.65) {inverts pages};
  \node[font=\scriptsize\ttfamily, text=acc, anchor=north] at (10.4, -0.65) {answers queries};
\end{tikzpicture}
$$

Crawling the web is graph traversal: the web is a directed graph whose
vertices are pages and whose edges are links, and the crawler runs
breadth-first search over it from a seed URL, bounded by a maximum depth
and restricted to a configurable domain, so the crawl stays inside its
assigned subset of the web. The frontier is a `bag_t` of pages still to
visit and the seen-set a `hashtable_t` of URLs already queued:

```algorithm
caption: $\textsc{Crawl}(s, k)$ — BFS over the web graph
input: a seed URL $s$, a depth bound $k$
bag $\gets$ queue containing $(seed, 0)$; seen $\gets$ hashtable containing seed
while bag is not empty do
  $(url, d) \gets$ remove from bag
  fetch $url$; save the page to disk
  if $d < k$ then
    for each link $u$ on the page, normalized, do
      if $u$ is internal and $u \notin$ seen then
        insert $u$ into seen; add $(u, d + 1)$ to bag
```

`pageScan` pulls the links off each fetched page, normalizes them, and
adds the internal, unseen ones to the bag. `pagedir_save` writes every
fetched page to a file named by an integer document ID (URL on the first
line, crawl depth on the second, raw HTML below) inside a directory
`pagedir_init` stamps with a `.crawler` sentinel so the later stages can
confirm they were handed a real crawl.

The indexer inverts those pages into a map. It walks that directory and,
for each word `normalizeWord` lowercases out of a page, updates an
`index_t`, a `hashtable_t` mapping each word to a `counters_t` that
tallies $(\mathit{docID} \to \mathit{count})$. `index_print` serializes it
to a plain text file, one word per line followed by its `docID count`
pairs; `index_load` reconstructs the same structure, so the querier reads
back exactly what the indexer wrote. Looking up a query term is $O(1)$ per
word rather than a scan over every document.

The querier answers ranked boolean queries. It parses them with implicit
`and` conjunctions and explicit `or` disjunctions, honoring precedence
(`and` binds tighter). Scores follow the operators: a conjunction takes
the minimum over its terms, a disjunction the sum,

$$
\operatorname{score}(A \text{ and } B, d) = \min(c_A(d),\, c_B(d)),
\qquad
\operatorname{score}(A \text{ or } B, d) = c_A(d) + c_B(d),
$$

where $c_w(d)$ counts occurrences of $w$ in document $d$. Those two rules
fall straight out of the `counters` module: `query_build` looks each word
up in the index, `query_intersection` walks two counter sets keeping the
minimum shared count, and `query_union` sums them. `query_print` then
sorts the surviving documents by score before printing. Everything is
valgrind-clean C, checked against the `memcheck` and `indextest` harnesses
in each module, with every container hand-rolled on the shared `libcs50`
primitives.

[web-search]: https://en.wikipedia.org/wiki/Web_search_engine
