---
title: Sum of Multiples
description: Common Problems Across Multiple Paradigms.
category:
  - exposition
draft: false
featured: true
image: cover6.gif
caption: disjunctive frequencies.
layout: article
date: 2023-06-21 00:00:00
navigation: true
---

# Project Euler, Problem 1

If we list all the natural numbers below 10 that are multiples of $3$ or $5$,
we get $3$, $5$, $6$ and $9$. The sum of these multiples is $23$.

Find the sum of all the multiples of $3$ and $5$ below $1000$.

<!--more-->

::inline-flex

:styled-button[more information]{href=https://projecteuler.net/archives}

:styled-button[code repository]{href=https://github.com/siavava/epsilon/tree/main}

::

## Utility Functions

Here, we just take a number $n$ and a list of divisors then check if any of the divisors divides $n$.

```haskell
-- | Check if any of the divisors divide the number n.
anyDivisor :: (Foldable c, Integral a) => a -> c a -> Bool
anyDivisor n divisors =
  any (\x -> n `mod` x == 0) divisors
  -- ^ NOTE: this short-circuits,
  --   i.e. stops as soon as it finds a single divisor.
```

## Approach 1: Exploiting Laziness

Generate a list of all the numbers below $1000$ that are multiples of $3$ or
$5$, then sum them.

```haskell
solve1 :: Int -> [Int] -> Int
solve1 bound divisors =
  sum $ nub $ filter (`anyDivisor` divisors) [1..bound-1]
  -- ^ sum the list of *unique* elements (nub)

-- >>> solve1 1000 [3,5]
-- 233168
```

### #1, Explained?

You might be thinking we do not need to generate a list of all the values,
and you would be right.

::alert
---
type: info
title: The "problem" with approach 1
---
[Haskell](https://www.haskell.org/) is a lazy language.
Instead of explicitly generating the entire list of values,
it keeps the combined specification at hand
and generates the values on-demand,
then discards each value as soon as it is no longer needed and
it is efficient to discard it.

Haskell's list mechanics are more in line with [generators](https://en.wikipedia.org/wiki/Generator_(computer_programming))
in [Python](https://www.python.org/), [C++](https://en.cppreference.com/w/cpp/language/generator),
and other non-functional languages.

::

## Approach 2: Tail Recursion

Generating a list of all values divisible by $3$ and $5$ when we are only interested in their sum is wasteful.
Here, the design of the language saved us, but laziness is not a universal feature,
especially in non-functional languages.
A _generally_ smarter approach would be to consider one number at a time, and only have
to allocate memory for one number at a time.

However, most functional programming languages disallow explicit iteration.
You see, much of computing with loops often involves mutating
some state that lives across the iterations,
and a dear principle of functional programming is that functions do not
mutate values.

### Motivation for Tail Recursion
Most functional languages prefer recursion over iteration,
since computing with explicit iteration _usually_ involves mutating
some state that lives across the iterations.

But recursion comes with its own problems, doesn't it?

Take, for instance, a simple recursive solution to the factorial function:

```python
def factorial(bound):
  acc = 1
  for curr in range(bound):
    acc *= curr             # mutating the accumulator
  return acc
```

The naive translation of the above into Haskell, which _mostly_ disallows
explicit iteration, would look a lot like:

```haskell
factorial :: Int -> Int
factorial n
  | n == 0 = 1
  | otherwise = n * factorial (n - 1)
```

There is one massive problem: recursive calls require a stack frame and,
afterward, unwinding to yield the final result.  
A call to `factorial 5` would result in the following stack trace:

```haskell
factorial 5
5 * (factorial 4)
5 * (4 * (factorial 3))
5 * (4 * (3 * (factorial 2)))
5 * (4 * (3 * (2 * (factorial 1))))
5 * (4 * (3 * (2 * (1 * (factorial 0)))))
5 * (4 * (3 * (2 * (1 * 1))))
5 * (4 * (3 * (2 * 1)))
5 * (4 * (3 * 2))
5 * (4 * 6)
5 * 24
120
```

Recursion not only gave us memory wastage, it also resulted in _unnecessary_ runtime overhead.
Sure, it still runs in linear time, but if everything takes twice as long as it should
**and** we can do better, shouldn't we?

The main idea behind [tail recursion](https://en.wikipedia.org/wiki/Tail_call)
is that if the recursive call is the last thing to happen in the function,
then we can pass the context forward and avoid setting up (and unwinding!)
the stack frame by having the terminating call return the complete
solution back to the original caller.

```python
def factorial(n, acc=1):
  if n == 0:
    return acc
  return factorial(n - 1, acc * n)
```

A similar solution in Haskell:
  
```haskell
factorial :: Int -> Int
factorial n = iter n 1
  where
    iter :: Int -> Int -> Int
    iter n acc
      | n == 0 = acc
      | otherwise = iter (n - 1) (acc * n)
```

Now, our stack trace looks like this:

```haskell
factorial 5
iter 5 1
iter 4 5
iter 3 20
iter 2 60
iter 1 120
iter 0 120
120
```

::alert
---
type: info
title: What is really happening in approach 2?
---
The canon Haskell compiler, GHC, is actually smart enough to recognize tail recursion
and unroll it into a loop under the hood.

As [Peter Deutsch](https://en.wikipedia.org/wiki/L._Peter_Deutsch) once said:
**To iterate is human, to recur, divine.**
::

### A Tail Recursive Solution to the Problem

Like most [coding interview advice](https://www.youtube.com/watch?v=XKu_SEDAykw)
would tell you, _please remember to solve the original problem!._

```haskell
solve2 :: Int -> [Int] -> Int
solve2 bound divisors = iter 0 0 bound
  where
    iter :: Int -> Int -> Int -> Int
    iter acc curr end
      | curr == end = acc
      | anyDivisor curr divisors
        = iter (acc + curr) (curr + 1) end
      | otherwise = iter acc (curr + 1) end

-- >>> solve2 1000 [3,5]
-- 233168
```

### #2, Explained?

Using tail recursion, we effectively iterate through all values in the range
and, when a value is a multiple of any of the divisors, we adjust the value of the accumulator
that is passed forward to the next iteration.

The terminating call eventually returns the value of the accumulator.

## Approach 3: Monadic State Mutation

As we saw, the tail call emulates iteration using recursion.
What if we wanted to _explicitly_ iterate?

Haskell allows you to do so if you hop through enough hoops and throw
some of the safety that functional programming languages provide.
That is, if you really, really, _really_ want to explicitly iterate **that badly**.

```haskell
solve3 :: Int -> [Int] -> Int
solve3 bound divisors = unsafePerformIO $ do
  
  total <- newIORef 0                     -- initialize sum to 0

  forM [1..bound-1] $ \curr -> do         -- iterate upto bound using curr as index
    when (anyDivisor curr divisors) $ do  -- when curr is a multiple...
      modifyIORef total (+ curr)          -- add curr to sum

  readIORef total                         -- return final value of sum

-- >>> solve3 1000 [3,5]
-- 233168
```

### #3, Explained

Instead of a tail recursion (which is unrolled into a loop by [GHC](https://www.haskell.org/ghc/)) anyway,
use the state monad to maintain the state of the accumulator
an explicit loop to check multiples.

::alert
---
type: warning
title: The problem with approach 3
---
This approach is **not** a [pure function](https://en.wikipedia.org/wiki/Pure_function).);
We mechanically mutate the internal state of the [monad](http://learnyouahaskell.com/a-fistful-of-monads) 
resort to a roundabout `unsafePerformIO` call to extract the internal state of the monad
(remember, we need to return an `Int`, not an `Int` wrapped up in an `IO` monad...).
But what we do is entirely unsafe and, were the internal state of the monad
an error value, the program would **most certainly** crash.

Considering that the compiler would have unrolled the tail recursion into a _safe_ loop anyway,
this approach is totally unwarranted.
::
