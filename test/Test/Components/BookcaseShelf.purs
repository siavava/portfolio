-- | Checks for one labelled shelf of the bookcase: it reads as the active
-- | shelf exactly when the selected book, matched by its whole path, stands
-- | on it — never with nothing selected, and never when empty.
module Test.Components.BookcaseShelf (suite) where

import Prelude

import App.Components.BookcaseShelf (ShelfBook, holdsSelection)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

book :: String -> ShelfBook
book path = { path, title: path, date: "2024-01-01" }

shelf :: Array ShelfBook
shelf = [ book "/projects/chess", book "/projects/search" ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "a shelf holding the selected book is active" true
    (holdsSelection (notNull "/projects/search") shelf)
  expect t "a shelf without the selected book is not" false
    (holdsSelection (notNull "/projects/compiler") shelf)
  expect t "no shelf is active with nothing selected" false (holdsSelection null shelf)
  expect t "an empty shelf is never active" false (holdsSelection (notNull "/projects/chess") [])
  expect t "a path that only starts like a book's is not that book" false
    (holdsSelection (notNull "/projects/chess-engine") shelf)
