---
title: "Logic Algorithms"
date: 2021-10-21
tag: "artificial intelligence"
repo: "https://github.com/lostflux/artificial-intelligence/tree/main/05-Logic"
featured: false
tech:
  - "Python"
  - "First Order Logic"
  - "AI"
summary: |-
  Solving Boolean satisfiability with the GSAT and WalkSAT local-search
  algorithms, applied to Sudoku puzzles encoded as propositional clauses.
references:
  - https://notes.amittai.studio/artificial-intelligence/logic-and-planning/propositional-logic
  - https://notes.amittai.studio/artificial-intelligence/logic-and-planning/propositional-inference
  - https://notes.amittai.studio/algorithms/intractability/np-completeness
---

[Boolean satisfiability][boolean-satisfiability]
(SAT) asks whether a propositional formula can be made true by some assignment
of its variables. It is
[NP-complete][np-completeness], so no known
algorithm decides it in polynomial time; a polynomial solution would settle
[P versus NP][p-versus]. This project
sidesteps the worst case with local search, trading completeness for speed, and
uses it to solve [Sudoku][sudoku] puzzles.

SAT solvers take conjunctive normal form,

$$
\Phi = \bigwedge_{i} \Bigl( \bigvee_{j} \ell_{ij} \Bigr),
$$

a conjunction of clauses, each clause a disjunction of literals $\ell_{ij}$. A
Sudoku board encodes as one Boolean variable $x_{r,c,d}$ per (row, column,
digit) triple, true when cell $(r, c)$ holds digit $d$; the code names each
variable by the three-digit string `rcd` and negates with a leading `-`. The
`Sudoku` class writes the rules out as clauses to a `.cnf` file — each cell
gets an at-least-one disjunction over its nine digits plus pairwise at-most-one
clauses, each row, column, and $3 \times 3$ block gets a clause per digit
forcing it to appear, and every given cell contributes a unit clause. Smaller
staged files (`one_cell`, `rows`, `rows_and_cols`, `rules`) build the encoding
up piece by piece for testing. A completed board is a satisfying assignment.

The `SAT` solver is generic: it reads any CNF file, maps each variable to an
index with a two-way dictionary, and starts from a random full assignment,
flipping one variable at a time.
[GSAT][gsat] and
[WalkSAT][walksat] share a noise parameter
(`threshold` $= 0.3$) and a flip budget (`max_iterations` $= 100{,}000$). On
each step GSAT, with probability $p$, flips a random variable, and otherwise
scans _all_ variables and flips the one whose flip leaves the most clauses
satisfied — hill climbing that stalls on local optima where no single flip
helps.

**WalkSAT** narrows the search. It first collects the currently unsatisfied
clauses, picks one at random and, with probability $p$, flips a random
variable in it; otherwise it considers only that clause's variables and flips
the one that leaves the most clauses satisfied. Restricting the greedy scan to
a single broken clause is what makes each step cheap.

```algorithm
caption: $\textsc{WalkSAT}(\Phi, p, n)$ — noisy local search for SAT
input: a CNF formula $\Phi$, noise probability $p$, a flip budget $n$
assign each variable a random truth value
repeat $n$ times
  if the assignment satisfies every clause then return it
  $C \gets$ a randomly chosen unsatisfied clause
  with probability $p$ do
    flip a random variable in $C$
  otherwise
    flip the variable in $C$ that leaves the most clauses satisfied
return failure
```

Neither algorithm is complete: on an unsatisfiable formula they simply exhaust
the flip budget without reporting that no assignment exists. On satisfiable
instances like a valid Sudoku they find an assignment quickly, which is the
regime this project targets.

[boolean-satisfiability]: https://en.wikipedia.org/wiki/Boolean_satisfiability_problem
[np-completeness]:        https://en.wikipedia.org/wiki/NP-completeness
[p-versus]:               https://en.wikipedia.org/wiki/P_versus_NP_problem
[sudoku]:                 https://en.wikipedia.org/wiki/Sudoku
[gsat]:                   https://en.wikipedia.org/wiki/GSAT
[walksat]:                https://en.wikipedia.org/wiki/WalkSAT
