---
title: "Generative Pre-trained Transformer"
date: 2023-09-17
tag: "deep learning"
repo: "https://github.com/lostflux/transfusion"
featured: true
tech:
  - "Python"
  - "PyTorch"
  - "Deep Learning"
summary: |-
  A GPT built from scratch in PyTorch — causal self-attention, learned
  positional embeddings, and six pre-norm transformer blocks — trained
  character by character on a corpus of 2023 AI articles and served behind a
  FastAPI endpoint.
references:
  - https://notes.amittai.studio/deep-learning
  - https://notes.amittai.studio/linear-algebra
---

A character-level
[GPT][generative-pre]
implemented from scratch in PyTorch — every module written out by hand, no
`nn.Transformer` shortcuts. It trains on a corpus of 2023 AI and technology
writing (the
[`siavava/ai-tech-articles`][hf-ai]
dataset, filtered to that year), building its vocabulary from the sorted set
of characters in the text, and generates one character at a time.

Attention works as a soft lookup: each token emits a query, a key, and a
value, and attends to the others by how well its query matches their keys:

$$
\operatorname{Attention}(Q, K, V)
= \operatorname{softmax}\!\left(\frac{Q K^\top}{\sqrt{d_k}}\right) V,
$$

with the $\sqrt{d_k}$ keeping dot products in softmax's well-behaved
range. In code a `Head` is three bias-free `nn.Linear` projections into a
`head_size` subspace, a registered lower-triangular `tril` buffer for the
**causal mask** that zeroes attention to future positions, and dropout on
the weights. `MultiHeadAttention` runs six such heads in parallel
($\text{head\_size} = 384 / 6 = 64$) and projects their concatenation back
to the model width, so different heads track different relationships.

$$
% caption: Both sublayers of a pre-norm transformer block sit on a residual stream —
% each adds its contribution to a running sum, which is what lets dozens of
% blocks train stably.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  st/.style={rectangle, draw=acc, fill=acc!8, minimum width=3.1cm, minimum height=0.7cm, inner sep=2pt}]
  \definecolor{acc}{HTML}{2348F2}
  \node (in) at (0, 0) {tokens + positions};
  \node[st] (attn) at (0, 1.3) {masked self-attention};
  \node[st] (mlp) at (0, 3.1) {feed-forward \texttt{MLP}};
  \node (out) at (0, 4.4) {logits};
  \coordinate (j1) at (0, 2.2);
  \coordinate (j2) at (0, 4.0);
  \fill (j1) circle (1.2pt);
  \fill (j2) circle (1.2pt);
  \draw[->] (in) -- (attn);
  \draw (attn) -- (j1);
  \draw[->] (j1) -- (mlp);
  \draw (mlp) -- (j2);
  \draw[->] (j2) -- (out);
  \draw[->] (in.east) .. controls (2.7, 0.4) and (2.7, 1.9) .. node[right, font=\scriptsize\ttfamily, text=acc]{residual} (j1);
  \draw[->] (j1) .. controls (2.7, 2.5) and (2.7, 3.7) .. node[right, font=\scriptsize\ttfamily, text=acc]{residual} (j2);
\end{tikzpicture}
$$

A `Block` is pre-norm: `x = x + sa(ln1(x))` then
`x = x + ffwd(ln2(x))`, where `FeedFoward` widens to four times the model
dimension through a `ReLU` and back. `GPTLanguageModel` stacks six of these
in an `nn.Sequential`, fronted by a token embedding table and a learned
position embedding table — attention alone is permutation-invariant, so the
positions supply order — and closed by a final `LayerNorm` and an `lm_head`
linear tie to the vocabulary. Weights initialize from a normal with standard
deviation `0.02`.

The trained configuration (`config.yml`) is small enough to run on one GPU:

- **context** 256 tokens, **model width** 384, **heads** 6, **layers** 6.
- **dropout** 0.2, **batch** 32, **AdamW** at learning rate $3\times10^{-4}$.
- **10,000 iterations**, with train and validation loss estimated over 200
  batches every 500 steps.

Training minimizes cross-entropy

$$
\mathcal{L} = -\sum_{t} \log p_\theta\!\left(x_{t+1} \mid x_{\le t}\right),
$$

and `generate` samples autoregressively — crop the context to the last 256
tokens, softmax the final logits, draw one character with
`torch.multinomial`, append it, and repeat. A FastAPI layer (`main.py`) loads
a saved checkpoint and exposes `GET /api/{query}`, returning 150 generated
characters as JSON.

[generative-pre]: https://en.wikipedia.org/wiki/Generative_pre-trained_transformer
[hf-ai]:          https://huggingface.co/datasets/siavava/ai-tech-articles
