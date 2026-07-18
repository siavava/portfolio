---
title: "Command-Line Utilities"
date: 2021-04-25
tag: "systems"
repo: "https://github.com/siavava/CS50.2"
featured: false
tech:
  - "Bash"
  - "C"
  - "Linux"
summary: "Three small command-line utilities in C: a wind-chill calculator, a word printer, and a self-resizing histogram builder for streamed numbers."
---

Three small command-line utilities written in C, each reading input and
writing to standard output in the Unix filter style.

**`chill`** computes the [wind chill][wind-chill]
from an air temperature $T$ (°F) and a wind speed $v$ (mph), using the
US National Weather Service formula:

$$
T_{wc} = 35.74 + 0.6215\,T - 35.75\,v^{0.16} + 0.4275\,T\,v^{0.16}.
$$

`computeChill` returns the value and `printTable` formats the output:
with no arguments the program sweeps a table over temperatures from
$-10$ to $40$ °F and winds from $5$ to $15$ mph; given a temperature it
varies wind alone, and given both it prints the single value.

**`words`** prints the words in a file one per line, scanning character
by character with `isalpha` and emitting each run of letters as a line,
reading from a named file or from standard input. **`histo`** reads a
stream of integers from standard input into sixteen fixed bins; when a
value overflows the current range the bin width doubles and the existing
counts are merged, so the histogram rescales itself to fit the data.

[wind-chill]: https://en.wikipedia.org/wiki/Wind_chill
