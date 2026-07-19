---
title: "AI / Tech Dataset"
date: 2023-11-04
tag: "data mining"
repo: "https://github.com/lostflux/functional-scraper"
url: "https://huggingface.co/datasets/siavava/ai-tech-articles"
featured: true
tech:
  - "Haskell"
  - "Python"
  - "Data Mining"
summary: |-
  A concurrent web scraper in Haskell that collected 17,000+ technology
  articles into an open dataset, built from composable arrow pipelines.
references:
  - https://notes.amittai.studio/algorithms/graphs/representations-and-traversal
  - https://notes.amittai.studio/algorithms/data-structures/hash-tables
---

A web scraper written in Haskell that collected 17,000+ articles from
technology publishers — [DeepMind][deepmind],
[MIT Technology Review][technologyreview],
[OpenAI][openai],
[Singularity Hub][singularityhub], and
[TechCrunch][techcrunch] — into an open dataset published on
[HuggingFace][hf-ai].

Extraction runs as an arrow pipeline. The parser (`MyData.Parser`) is built
on [HXT][hxt], whose
[arrows][afp-arrows] generalize a
plain function $b \to c$ into a composable stage over an XML tree.
`loadPage` fetches the page with `simpleHttp`, hands the bytes to
`readString [withParseHTML yes, withWarnings no]`, and runs arrows over
the resulting DOM with `runX`. Each field is its own small arrow chain:
`getWords` descends with `//>` and merges paragraph and heading nodes with
the choice operator `<+>` (`hasName "p" <+> hasName "h1" <+> ...`), then
`deep (isText >>> getText)` pulls their text; `getLinks` selects `a` nodes
and reads `getAttrValue "href"`; `getTitle` and `getYear` do the same over
their tags. The results assemble a `WebPage` record — `title`, `year`,
`links`, and the body `text` as a prefix tree.

$$
% caption: A page enters at $\texttt{simpleHttp}$, which fetches it;
% $\texttt{readString}$ builds the DOM, and $\texttt{runX}$ runs the HXT
% arrows that fill a $\texttt{WebPage}$; the keyword gate keeps the page
% only if enough target words hit.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  st/.style={rectangle, draw=acc, fill=acc!8, minimum width=1.9cm, minimum height=0.8cm, inner sep=2pt},
  lb/.style={font=\scriptsize\ttfamily, text=acc, anchor=north}]
  \definecolor{acc}{HTML}{2348F2}
  \node[st] (fetch) at (0, 0) {fetch};
  \node[st] (parse) at (2.7, 0) {parse HTML};
  \node[st] (arrows) at (5.4, 0) {HXT arrows};
  \node[st] (gate) at (8.1, 0) {keyword gate};
  \node[st] (store) at (10.8, 0) {store + queue};
  \draw[->] (fetch) -- (parse);
  \draw[->] (parse) -- (arrows);
  \draw[->] (arrows) -- (gate);
  \draw[->] (gate) -- (store);
  \node[lb] at (0, -0.62) {simpleHttp};
  \node[lb] at (2.7, -0.62) {readString};
  \node[lb] at (5.4, -0.62) {runX};
  \node[lb] at (8.1, -0.62) {hasKeyWords};
\end{tikzpicture}
$$

A `Config` record loaded from `config.yml` with `Data.Yaml` drives the run,
keeping the tuning in configuration rather than code: `domains` are the seed URLs, `targets`
are the keywords a page is scored against, `limit` caps the work queue,
and `wordcount` sets how many keyword hits a page needs to be kept.
Retargeting the scraper at a new publisher is a line in `config.yml`, not
a change to the parser.

`Main.iter` walks each publisher's page graph outward from the seed URLs by
breadth-first search, holding the frontier as a queue and the visited URLs as
a `Data.Set`; set difference (`\\`) drops links already
seen, and `isAllowed` keeps the crawl inside the seed domains. Each fetched
page's body is folded into a `Trie` of words, and `hasKeyWords` accepts the
page only when at least `wordcount` targets are present — the filter that
kept the collection on-topic across a run of 17,000-plus articles.

The result is cleaned, titled, dated article text, released open-source
for downstream mining. Collaborative project with
[Aimen Abdulaziz][aimen-abdulaziz] and
[Angelic McPherson][angelic-mcpherson].

[deepmind]:          https://deepmind.com/
[technologyreview]:  https://www.technologyreview.com/
[openai]:            https://openai.com/
[singularityhub]:    https://singularityhub.com/
[techcrunch]:        https://techcrunch.com/
[hf-ai]:             https://huggingface.co/datasets/siavava/ai-tech-articles
[hxt]:               https://wiki.haskell.org/HXT
[afp-arrows]:        https://www.cse.chalmers.se/~rjmh/afp-arrows.pdf
[aimen-abdulaziz]:   https://www.linkedin.com/in/aimen-abdulaziz/
[angelic-mcpherson]: https://www.linkedin.com/in/angelic-mcpherson/
