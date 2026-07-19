---
title: "Parts-Of-Speech Tagging"
date: 2021-03-02
tag: "artificial intelligence"
repo: "https://github.com/lostflux/elementary-java/tree/main/Problem%20Sets/PS-5"
featured: false
tech:
  - "Java"
  - "Markov Decision Processes"
summary: |-
  Part-of-speech tagging as a hidden Markov model, decoded with the Viterbi
  algorithm over tag-transition and word-emission probabilities.
references:
  - https://notes.amittai.studio/natural-language-processing/sequences/sequence-labeling
  - https://notes.amittai.studio/artificial-intelligence/uncertainty/reasoning-over-time
---

A [hidden Markov model][hidden-markov]
treats a sentence as a sequence of hidden states — the part-of-speech tags —
that emit the observed words. Tagging recovers the tag sequence most likely to
have produced the sentence, and the
[Viterbi algorithm][viterbi-algorithm] finds it
exactly in time linear in the sentence length.

The model rests on two distributions, both estimated by counting over a tagged
corpus: transition probabilities $P(t_i \mid t_{i-1})$ between adjacent tags,
and emission probabilities $P(w_i \mid t_i)$ of a word given its tag. The `HMM`
class keeps them as two nested maps, `states` (tag to word to probability) and
`transitions` (tag to following tag to probability), trained by reading paired
sentence and tag files — the Brown corpus in `brown-train-sentences.txt` and
`brown-train-tags.txt` — with a `#` token marking each sentence start. Under the
Markov assumption, the joint probability of a sentence $w_{1:n}$ and a tag
sequence $t_{1:n}$ factors as

$$
P(w_{1:n}, t_{1:n}) = \prod_{i=1}^{n} P(t_i \mid t_{i-1})\, P(w_i \mid t_i),
$$

and tagging asks for the tag sequence that maximizes it. Enumerating all
$|T|^{n}$ sequences is exponential, so the search is folded into a dynamic
program.

The decoder works from a single recurrence. Let $v_i(t)$ be the probability of
the best tag sequence ending in tag $t$ at position $i$; it depends only on the
previous column,

$$
v_i(t) = P(w_i \mid t)\, \max_{s}\; v_{i-1}(s)\, P(t \mid s),
$$

so one left-to-right sweep fills an $n \times |T|$ table, and back-pointers
recover the winning sequence. A greedy tagger that commits to the best tag at
each word can be led astray by a locally attractive choice; Viterbi keeps every
option open until the whole sentence is scored. Probabilities are accumulated in
log space, turning the products into sums and avoiding underflow on long
sentences.

Laid out as a grid of positions by tags, the recurrence fills one column from the
one before it, and every cell records which predecessor it chose — the
back-pointer that lets the winning sequence be traced once the last column is
scored:

$$
% caption: A Viterbi trellis over four words and three candidate tags. Each cell
% holds $v_i(t)$, the score of the best tag path ending in tag $t$ at position $i$;
% thin edges are the transitions weighed at each step. The accent path is the
% winner the back-pointers recover, traced right to left from the highest-scoring
% f\/inal cell.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  nd/.style={circle, draw=acc, fill=acc!8, minimum size=5.5mm, inner sep=0pt},
  bp/.style={circle, draw=acc, thick, fill=acc!18, minimum size=5.5mm, inner sep=0pt}]
  \definecolor{acc}{HTML}{2348F2}
  \coordinate (a1) at (0,2);   \coordinate (a2) at (0,1);   \coordinate (a3) at (0,0);
  \coordinate (b1) at (2.2,2); \coordinate (b2) at (2.2,1); \coordinate (b3) at (2.2,0);
  \coordinate (c1) at (4.4,2); \coordinate (c2) at (4.4,1); \coordinate (c3) at (4.4,0);
  \coordinate (d1) at (6.6,2); \coordinate (d2) at (6.6,1); \coordinate (d3) at (6.6,0);
  \draw[thin, black!40] (a1)--(b1) (a1)--(b2) (a1)--(b3) (a2)--(b1) (a2)--(b2) (a2)--(b3) (a3)--(b1) (a3)--(b2) (a3)--(b3);
  \draw[thin, black!40] (b1)--(c1) (b1)--(c2) (b1)--(c3) (b2)--(c1) (b2)--(c2) (b2)--(c3) (b3)--(c1) (b3)--(c2) (b3)--(c3);
  \draw[thin, black!40] (c1)--(d1) (c1)--(d2) (c1)--(d3) (c2)--(d1) (c2)--(d2) (c2)--(d3) (c3)--(d1) (c3)--(d2) (c3)--(d3);
  \draw[acc, line width=1pt] (a1)--(b2) (b2)--(c3) (c3)--(d2);
  \node[nd] at (a2) {}; \node[nd] at (a3) {};
  \node[nd] at (b1) {}; \node[nd] at (b3) {};
  \node[nd] at (c1) {}; \node[nd] at (c2) {};
  \node[nd] at (d1) {}; \node[nd] at (d3) {};
  \node[bp] at (a1) {}; \node[bp] at (b2) {}; \node[bp] at (c3) {}; \node[bp] at (d2) {};
  \node[anchor=east, text=black!60] at (-0.55,2) {DET};
  \node[anchor=east, text=black!60] at (-0.55,1) {NOUN};
  \node[anchor=east, text=black!60] at (-0.55,0) {VERB};
  \node[font=\ttfamily, text=black!70, anchor=north] at (0,-0.55) {the};
  \node[font=\ttfamily, text=black!70, anchor=north] at (2.2,-0.55) {cat};
  \node[font=\ttfamily, text=black!70, anchor=north] at (4.4,-0.55) {saw};
  \node[font=\ttfamily, text=black!70, anchor=north] at (6.6,-0.55) {dogs};
\end{tikzpicture}
$$

```algorithm
caption: $\textsc{Viterbi}(w_{1:n})$ — decode the most likely tag sequence
input: a sentence $w_1 \ldots w_n$, transitions $P(t \mid s)$, emissions $P(w \mid t)$
for each tag $t$ do
  $v_1(t) \gets P(t \mid \textsc{Start})\, P(w_1 \mid t)$
for $i \gets 2$ to $n$ do
  for each tag $t$ do
    $v_i(t) \gets P(w_i \mid t)\, \max_{s}\; v_{i-1}(s)\, P(t \mid s)$
    $\mathrm{back}_i(t) \gets \operatorname{arg\,max}_{s}\; v_{i-1}(s)\, P(t \mid s)$
return the sequence traced back from $\operatorname{arg\,max}_{t} v_n(t)$
```

A word never seen in training has zero emission probability under every tag,
which would zero out any path through it. To keep such a word from killing an
otherwise good sequence, `HMM.viterbi` charges a fixed `unseenPenalty` of $-100$
in log space for an unseen word, letting the transition structure pick a
plausible tag from context alone. Run over held-out data, `testFile` tags `brown-test-sentences.txt` and
scores its output against `brown-test-tags.txt`, counting correct against
incorrect tags.

[hidden-markov]:     https://en.wikipedia.org/wiki/Hidden_Markov_model
[viterbi-algorithm]: https://en.wikipedia.org/wiki/Viterbi_algorithm
