---
order: 4
month: 1
year: 2023
date: 2023-09-17
title: 'Generative Pre-trained Transformer'
repo: 'https://github.com/siavava/transfusion'
tech:
  - Python
  - PyTorch
  - Deep Learning
category: 'featured-project'
featured: true
navigation: false
tag: 'deep learning'
---

For fun, I implemented the [Generative Pre-trained Transformer][gpt] (GPT) architecture
in PyTorch. GPT is a language model that uses a transformer architecture
to generate text. I trained the model on the [tiny Shakespeare dataset][tinyshakes]
and used it to generate text in the style of Shakespeare.

Transformers are a type of neural network architecture that employes techniques such as:

- [Self-attention][self-attention], which allows the model to learn the relationships
  between different parts of the input data.
- [Positional encoding][positional-encoding], which allows the model to learn the
  relative positions of the input data.
- [Multi-head attention][multi-head-attention], which allows the model to learn
  different relationships between different parts of the input data.
- [Residual connections][residual-connections], which allows the model to learn
  the difference between the input data and the output data.

[gpt]:                  https://openai.com/research/gpt-4
[tinyshakes]:           https://www.tensorflow.org/datasets/catalog/tiny_shakespeare

[self-attention]:       https://towardsdatascience.com/illustrated-self-attention-2d627e33b20a
[positional-encoding]:  https://kazemnejad.com/blog/transformer_architecture_positional_encoding/
[multi-head-attention]: https://towardsdatascience.com/illustrated-self-attention-2d627e33b20a
[residual-connections]: https://towardsdatascience.com/illustrated-self-attention-2d627e33b20a
