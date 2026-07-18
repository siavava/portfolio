---
title: "Relational Database App"
date: 2022-10-20
tag: "systems"
repo: "https://github.com/lostflux/relational"
featured: true
tech:
  - "Python"
  - "MySQL"
  - "Database Systems"
summary: "A MySQL editorial-management system for an academic journal, driven from a Python CLI, with the manuscript lifecycle enforced by foreign keys, triggers, and stored routines on the database side."
references:
  - https://notes.amittai.studio/algorithms/data-structures/b-trees
---

A [MySQL](https://www.mysql.com/) editorial-management system for an
academic journal, driven from a [Python](https://www.python.org/)
command-line client. People sign in as an `Admin`, `Author`, `Reviewer`,
or `Editor`, and the schema carries a manuscript through its whole life:
submission, assignment to reviewers, scoring, an accept/reject decision,
typesetting, and finally placement in a published issue. The invariants
that keep that pipeline honest live in [SQL](https://en.wikipedia.org/wiki/SQL)
triggers and stored routines, not in the client.

**The schema.** `Manuscript` is the hub. Each manuscript carries a
research-interest code (`RICodes`), an assigned `Editor`, and — once
placed — an `Issue`. Two junction tables record the many-to-many facts:
`Manuscript_Author` links a manuscript to its authors and keeps an
`author_ordinal` so the lead author is just ordinal 1, and
`Reviewer_has_Manuscript` holds each reviewer's five scores
(appropriateness, clarity, methodology, experimental, recommendation),
constrained to the range 1 to 10. `Reviewer_has_RICodes` and
`Journal_has_RICodes` attach interest codes to reviewers and journals;
`Author` and `Reviewer` both point at `Affiliation`, and `Editor` and
`Issue` both point at `Journal`. A single `credentials` table unifies
logins across all four roles through a `(user_type, type_id)` pair.

$$
% caption: Manuscript is the hub of the editorial schema: it references RICodes,
% Editor, and Issue directly, and is joined to Author and Reviewer through
% the Manuscript_Author and Reviewer_has_Manuscript tables. Arrows run from
% the row holding the foreign key to the table it references.
\begin{tikzpicture}[>=stealth, font=\footnotesize,
  tb/.style={rectangle, draw=acc, fill=acc!8, align=left, inner sep=4pt,
             font=\scriptsize\ttfamily},
  hub/.style={rectangle, draw=acc, fill=acc!12, align=left, inner sep=4pt,
              font=\scriptsize\ttfamily}]
  \definecolor{acc}{HTML}{2348F2}
  \node[hub] (m)  at (0,0)    {Manuscript\\manuscript\_number (pk)\\RICodes\_code (fk)\\Editor\_editor\_ID (fk)\\Issue\_issue\_ID (fk)};
  \node[tb]  (ri) at (0,3.3)  {RICodes\\code (pk)\\interest};
  \node[tb]  (ed) at (4.4,2)  {Editor\\editor\_ID (pk)\\Journal\_journal\_ID (fk)};
  \node[tb]  (is) at (4.4,-2) {Issue\\issue\_ID (pk)\\year, period\\Journal\_journal\_ID (fk)};
  \node[tb]  (ma) at (-4.9,2) {Manuscript\_Author\\Manuscript\_manuscript\_number (fk)\\Author\_author\_ID (fk)\\author\_ordinal};
  \node[tb]  (au) at (-4.9,4.7) {Author\\author\_ID (pk)\\Affiliation\_affiliation\_ID (fk)};
  \node[tb]  (rm) at (-4.9,-2) {Reviewer\_has\_Manuscript\\Reviewer\_reviewer\_ID (fk)\\Manuscript\_manuscript\_number (fk)\\clarity, methodology};
  \node[tb]  (rv) at (-4.9,-4.7) {Reviewer\\reviewer\_ID (pk)\\Affiliation\_affiliation\_ID (fk)};
  \draw[->, black!50] (m) -- (ri);
  \draw[->, black!50] (m) -- (ed);
  \draw[->, black!50] (m) -- (is);
  \draw[->, black!50] (ma) -- (m);
  \draw[->, black!50] (ma) -- (au);
  \draw[->, black!50] (rm) -- (m);
  \draw[->, black!50] (rm) -- (rv);
\end{tikzpicture}
$$

**Logic in the database.** Triggers move the workflow rules out of the
client and into the engine, where they fire for every writer.
`AutoRejectManuscriptOnNoReviewers` runs before a manuscript is inserted:
if no reviewer holds its research-interest code, the row is stamped
`rejected` on arrival rather than entering a queue that can never clear.
When a reviewer resigns, `DeleteAssignmentOnReviewerResign` clears their
assignments and code links, and `ResetManuscriptStatusonReviewerResign`
inspects each manuscript they leave behind: if it now has no reviewer but
another qualified one exists, the manuscript is reset to `Submitted` and
a `SIGNAL` message is raised; otherwise it is set to `Rejected`.
`AutoAcceptManuscript` collapses a step — a status set to `Accepted`
immediately becomes `Typesetting`. And `IndexAuthor`, `IndexReviewer`,
and `IndexEditor` each fire after an insert to create the matching
`credentials` row, so every new person is a valid login without a second
statement from the client.

**Stored routines and views.** The `MakeDecision` procedure averages a
manuscript's reviewer scores and returns `Accepted` when the total
reaches 40, `Rejected` below it. Read-side rollups are packaged as
views: `ReviewQueue` gathers every under-review manuscript with its
reviewers concatenated into one row, `PublishedIssues` lists the
contents of each completed issue in page order, and
`LeadAuthorManuscripts` filters `Manuscript_Author` down to
`author_ordinal = 1`.

**The Python side is thin.** `main.py` opens the connection and reads a
user ID; role modules (`author.py`, `editor.py`, `reviewer.py`) issue
parameterized statements through `dbutils.py`. A `/rebuild` flag
reconstructs the tables and a `/populate` flag seeds sample data;
otherwise only the two admin accounts exist. The interesting
work — the constraints, the automation, the consistency guarantees — sits
in the schema.

Lookups by key resolve through the engine's indexes — balanced
B-trees — rather than a full table scan.

Collaborative project with
[Ke Lou](https://www.linkedin.com/in/ke-lou-898301133).
