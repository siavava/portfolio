---
title: "Societal Attitudes Toward AI"
date: 2023-11-20
tag: "data mining"
repo: "https://github.com/lostflux/data-mining-project"
url: "https://github.com/siavava/data-mining-project/blob/main/report.pdf"
featured: true
tech:
  - "Python"
  - "LaTeX"
  - "NLP"
summary: "Mining a corpus of technology articles for how public sentiment and vocabulary around AI have shifted across time."
references:
  - https://notes.amittai.studio/natural-language-processing/semantics/vector-semantics-and-embeddings
  - https://notes.amittai.studio/natural-language-processing/classification/sentiment-and-affect-lexicons
  - https://notes.amittai.studio/linear-algebra
---

How has public sentiment toward AI shifted over time, and what events
moved it? This project mines the
[technology-article dataset][hf-ai]
— 17,092 articles and 28 million words spanning 2000 to 2023, drawn from
news outlets and AI labs — for that story. Three Jupyter notebooks carry
the work: one profiles the dataset, one scores sentiment, and one runs the
Procrustes comparison.

**Topic modeling surfaces the themes.** After Porter stemming and English
stopword removal, a gensim `LdaModel` fit over a `corpora.Dictionary` of
the articles extracts ten latent topics, each a distribution over words
and each article a mixture over topics. The top topics name the recurring
threads of the discourse: chatbots and privacy, deep learning and
DeepMind, autonomy and security, the metaverse.

**Sentiment tracks the tone.** nltk's `SentimentIntensityAnalyzer` scores
each article on four axes (positive, negative, neutral, and a compound
aggregate), averaged by year. The positive, negative, and neutral bands
stay fairly flat; the compound score is what jumps, and reading it per
topic rather than over the whole corpus exposes swings the global average
smooths away.

**Procrustes analysis compares the years.** Each year's articles produce
an LDA topic-distribution matrix, and two years are not directly
comparable, since a distribution is defined only up to rotation and scale.
`scipy.spatial.procrustes` standardizes both matrices and finds the
orthogonal $R$ that best overlays one on the other,

$$
\min_{R^\top R = I}\, \lVert A R - B \rVert_F,
$$

solved in closed form from the SVD $B^\top A = U \Sigma V^\top$, giving
$R = U V^\top$; the leftover residual is the _disparity_ between the two
years. Running it on consecutive years, and on every year against 2022,
turns the drift of the AI conversation into a single number per pair. The
disparities spike around the dot-com bust of 2000–2002, again through
2013–2016, and then climb sharply from 2018 onward, peaking across
2021–2023 as large language models entered the discourse.

The [full report][data-mining]
has the results. Collaborative project with
[Aimen Abdulaziz][aimen-abdulaziz] and
[Angelic McPherson][angelic-mcpherson].

[hf-ai]:             https://huggingface.co/datasets/siavava/ai-tech-articles
[data-mining]:       https://github.com/siavava/data-mining-project/blob/main/report.pdf
[aimen-abdulaziz]:   https://www.linkedin.com/in/aimen-abdulaziz/
[angelic-mcpherson]: https://www.linkedin.com/in/angelic-mcpherson/
