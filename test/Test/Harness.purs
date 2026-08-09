-- | ## Test.Harness
-- |
-- | Minimal assertion harness: a mutable tally of failures, `expect` for
-- | structural equality, `expectContains` for substring smoke checks, and
-- | a `report` that throws (non-zero exit) when anything failed.
module Test.Harness
  ( Tally
  , expect
  , expectContains
  , newTally
  , report
  ) where

import Prelude

import Data.String (Pattern(..), contains)
import Effect (Effect)
import Effect.Class.Console (error, log)
import Effect.Exception (throw)
import Effect.Ref (Ref)
import Effect.Ref as Ref

type Tally = { failures :: Ref Int, total :: Ref Int }

newTally :: Effect Tally
newTally = { failures: _, total: _ } <$> Ref.new 0 <*> Ref.new 0

failWith :: Tally -> String -> String -> String -> Effect Unit
failWith tally label expected actual = do
  Ref.modify_ (_ + 1) tally.failures
  error ("✗ " <> label)
  error ("  expected: " <> expected)
  error ("  actual:   " <> actual)

expect :: forall a. Eq a => Show a => Tally -> String -> a -> a -> Effect Unit
expect tally label expected actual = do
  Ref.modify_ (_ + 1) tally.total
  when (expected /= actual) (failWith tally label (show expected) (show actual))

expectContains :: Tally -> String -> String -> String -> Effect Unit
expectContains tally label needle haystack = do
  Ref.modify_ (_ + 1) tally.total
  when (not (contains (Pattern needle) haystack))
    (failWith tally label ("… containing " <> show needle) haystack)

report :: Tally -> Effect Unit
report tally = do
  failures <- Ref.read tally.failures
  total <- Ref.read tally.total
  if failures == 0 then log ("✓ all " <> show total <> " assertions passed")
  else throw (show failures <> " of " <> show total <> " assertions failed")
