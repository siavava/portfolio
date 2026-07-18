---
title: "Data Structures"
date: 2021-05-13
tag: "data structures and algorithms"
repo: "https://github.com/siavava/CS50.3"
featured: false
tech:
  - "Bash"
  - "C"
  - "Linux"
  - "Data Structures"
summary: "Four reusable C modules — a bag, a counter set, a set, and a hashtable — where the hashtable is an array of sets that chains collisions for expected constant-time lookup."
references:
  - https://notes.amittai.studio/algorithms/data-structures/hash-tables
---

Four reusable container modules in C, each an opaque type behind a small
allocate / insert / find / iterate / free interface.

**Bag and counters.** A [bag](https://en.wikipedia.org/wiki/Set_(abstract_data_type))
is an unordered collection of `void*` items, implemented as a singly
linked list used as a stack: `bag_insert` pushes onto the head and
`bag_extract` pops any item back off. A counter set trades items for
tallies — `counters_add`, keyed on an `int`, either starts a new count at
one or increments an existing one over the same linked-list backing.

**Set and hashtable.** A [set](https://en.wikipedia.org/wiki/Set_(abstract_data_type))
stores `(char* key, void* item)` pairs in a linked list, copying each key
string and rejecting duplicates, with `set_find` returning an item by
key. A [hashtable](https://en.wikipedia.org/wiki/Hash_table) presents the
same interface but scales it: it holds an array of `num_slots` sets and
routes each key through Bob Jenkins' one-at-a-time hash to a slot, so
`hashtable_insert` and `hashtable_find` delegate to a short per-slot set.
Chaining collisions inside those sets turns the set's linear scan into an
expected $O(1)$ lookup.
