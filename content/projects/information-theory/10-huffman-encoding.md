---
title: "Huffman Coding"
date: 2021-03-01
tag: "information theory"
repo: "https://github.com/lostflux/tau"
featured: false
tech:
  - "Java"
  - "Information Theory"
summary: "Lossless text compression by Huffman coding — a greedy frequency tree that gives frequent characters the shortest prefix-free codes."
references:
  - https://notes.amittai.studio/algorithms/greedy/huffman-codes
  - https://notes.amittai.studio/algorithms/greedy/the-greedy-method
---

Lossless text compression by [Huffman
coding](https://en.wikipedia.org/wiki/Huffman_coding#Compression).
Frequent characters get short binary codes and rare ones long codes, and
no code is a prefix of another, so the compressed stream decodes back to
the original with no ambiguity.

**Greedy construction.** The codes come from a binary tree built bottom
up. Start with one leaf per character, keyed by its frequency, and
repeatedly merge the two lowest-frequency nodes under a new parent whose
frequency is their sum, until a single tree remains. Reading the tree
root-to-leaf — 0 for a left branch, 1 for a right — gives each character
its code.

```algorithm
caption: $\textsc{Huffman}(C)$ — build an optimal prefix code from frequencies
input: characters $C$, each with frequency $f[c]$
$Q \gets$ min-priority queue over $C$, keyed by $f$
for $i \gets 1$ to $\lvert C \rvert - 1$ do
  $x \gets \textsc{Extract-Min}(Q)$
  $y \gets \textsc{Extract-Min}(Q)$
  $z \gets$ new node with children $x, y$ and $f[z] \gets f[x] + f[y]$
  insert $z$ into $Q$
return $\textsc{Extract-Min}(Q)$
```

$$
% caption: The Huffman tree for frequencies a:5 b:2 c:1 d:1 puts rare symbols
% deepest. Each internal node holds the summed frequency of its subtree;
% reading the 0/1 edge labels from the root to a leaf spells that symbol's
% code — a = 0, b = 10, c = 110, d = 111.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  lf/.style={rectangle, draw=black!55, minimum size=6mm, inner sep=3pt, font=\scriptsize\ttfamily},
  nd/.style={circle, draw=black!55, minimum size=6mm, inner sep=1pt, font=\scriptsize},
  el/.style={font=\scriptsize\ttfamily, text=acc, inner sep=1.5pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node[nd] (r)  at (2,3) {9};
  \node[lf] (a)  at (0.6,2) {a:5};
  \node[nd] (n4) at (3.5,2) {4};
  \node[lf] (b)  at (2.4,1) {b:2};
  \node[nd] (n2) at (4.8,1) {2};
  \node[lf] (c)  at (3.9,0) {c:1};
  \node[lf] (d)  at (5.7,0) {d:1};
  \draw[black!45] (r)--(a)   node[el, midway, above left] {0};
  \draw[black!45] (r)--(n4)  node[el, midway, above right] {1};
  \draw[black!45] (n4)--(b)  node[el, midway, above left] {0};
  \draw[black!45] (n4)--(n2) node[el, midway, above right] {1};
  \draw[black!45] (n2)--(c)  node[el, midway, above left] {0};
  \draw[black!45] (n2)--(d)  node[el, midway, above right] {1};
\end{tikzpicture}
$$

**Prefix-free decoding.** Because every symbol lands on a leaf, no codeword is a
prefix of another, and the compressed stream needs no separators between symbols.
Decoding walks the tree from the root, branching left on a 0 and right on a 1;
the moment it reaches a leaf it emits that symbol and jumps back to the root. Each
input bit is read once, so decoding is linear in the length of the stream.

**Why the greedy choice is optimal.** A prefix code is exactly a labeling
where every character is a leaf, so no code sits on the path to another.
The cost of a tree is the expected code length

$$
\bar{L} = \sum_{c \in C} f[c]\,\ell(c),
$$

where $\ell(c)$ is the depth of leaf $c$. Merging the two rarest symbols
first is safe because they can always be pushed to the deepest level of
some optimal tree without raising $\bar{L}$; induction on the merges then
gives a globally optimal code. No prefix code beats it.

How close is that to the theoretical floor? Shannon's source coding theorem
sets the entropy

$$
H(X) = -\sum_{c \in C} p[c] \log_2 p[c]
$$

as the average number of bits per symbol no lossless code can undercut, where
$p[c]$ is the symbol's probability. Huffman coding lands within one bit of it,

$$
H(X) \le \bar{L} < H(X) + 1,
$$

the slack being the cost of using a whole number of bits per symbol when the
ideal length $-\log_2 p[c]$ is usually fractional. The gap shrinks to nothing when
the probabilities are exact powers of $\tfrac{1}{2}$, and it is amortized away in
practice by coding blocks of symbols at once.
