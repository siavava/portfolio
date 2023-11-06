---
order: 4
month: 1
year: 2023
date: 2023-11-04
title: 'AI / Tech Dataset'
url: 'https://huggingface.co/datasets/siavava/ai-tech-articles'
repo: 'https://github.com/siavava/scrape.hs'
tech:
  - Haskell
  - Python
  - Data Mining
featured: true
navigation: false
tag: 'data mining'
---

Wrote a functional program in Haskell to scrape 3000+ articles from
online technology websites such as
- [TechCrunch][tech-crunch]
- [MIT Tech Review][mit-tech-review]
- [Singularity Hub][singuilarity-hub]
- [DeepMind][deepmind],
- [OpenAI][openai],
- [Towards Data Science][towards-data-science]
- [Analytics Vidhya][analytics-vidhya]

The scraper uses [Haxl][haxl] and [Arrows][arrows], among other functional programming patterns
to ensure concurrency and efficiency.
The articles were used for a subsequent study on the changing attitudes of society toward technology.

The dataset is open-source and available on [HuggingFace][huggingface].

Collaborative project with [Aimen Abdulaziz][aimen-abaziz] and [Angelic McPherson][angelic-mcpherson].

[tech-crunch]:            https://techcrunch.com/
[deepmind]:               https://deepmind.com/
[analytics-vidhya]:       https://www.analyticsvidhya.com/
[openai]:                 https://openai.com/
[singuilarity-hub]:       https://singularityhub.com/
[mit-tech-review]:        https://www.technologyreview.com/
[towards-data-science]:   https://towardsdatascience.com/
[haxl]:                   https://engineering.fb.com/2014/06/10/web/open-sourcing-haxl-a-library-for-haskell/
[arrows]:                 https://www.cse.chalmers.se/~rjmh/afp-arrows.pdf
[aimen-abaziz]:           https://www.linkedin.com/in/aimen-abdulaziz/
[angelic-mcpherson]:      https://www.linkedin.com/in/angelic-mcpherson/
[huggingface]:            https://huggingface.co/datasets/siavava/ai-tech-articles
