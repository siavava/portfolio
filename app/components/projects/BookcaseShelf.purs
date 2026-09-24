-- | ## BookcaseShelf
-- |
-- | The setup composable behind `BookcaseShelf.vue`, one labelled shelf of
-- | the bookcase: tells the label whether the selected book stands on this
-- | shelf, so the shelf holding the selection reads as the active one. The
-- | SFC keeps only the prop and emit macros plus one call here.
module App.Components.BookcaseShelf
  ( BookcaseShelfArgs
  , BookcaseShelfBindings
  , ShelfBook
  , holdsSelection
  , setup
  ) where

import Prelude

import Data.Foldable (any)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Vue (Computed, computed)

-- | One spine on the shelf.
type ShelfBook = { path :: String, title :: String, date :: String }

type BookcaseShelfArgs =
  { -- | Reads the `books` prop — the spines on this shelf.
    books :: Effect (Array ShelfBook)
  -- | Reads the `selectedPath` prop; null when nothing is selected.
  , selectedPath :: Effect (Nullable String)
  }

type BookcaseShelfBindings =
  { -- | Whether the selected book is one of this shelf's.
    hasSelection :: Computed Boolean
  }

-- | Whether the selected path, if any, is one of the books'.
holdsSelection :: Nullable String -> Array ShelfBook -> Boolean
holdsSelection selectedPath books =
  let
    selected = toMaybe selectedPath
  in
    any (\book -> selected == Just book.path) books

-- | Watches the selection against this shelf's books.
setup :: BookcaseShelfArgs -> Effect BookcaseShelfBindings
setup args = do
  hasSelection <- computed do
    books <- args.books
    selected <- args.selectedPath
    pure (holdsSelection selected books)
  pure { hasSelection }
