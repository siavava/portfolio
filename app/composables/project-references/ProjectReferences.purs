-- | ## ProjectReferences
-- |
-- | The reader's end-of-article reference list. The project's own repo
-- | and live link lead; frontmatter URLs into the notes site follow,
-- | resolved against the build-time notes index for their real titles
-- | (subject-index pages fall back to a small label map). The notes
-- | index and URL parsing live behind the FFI edge; everything else is
-- | pure.
module App.Composables.ProjectReferences
  ( ProjectDoc
  , Reference
  , ReferencesBindings
  , setup
  ) where

import Prelude

import Data.Array (catMaybes)
import Data.Maybe (Maybe(..), fromMaybe, isJust, maybe)
import Data.Nullable (Nullable, toMaybe)
import Data.String (Pattern(..), contains, stripSuffix)
import Data.String.CodeUnits as CU
import Effect (Effect)
import Vue (Computed, Ref, computed, read)

-- | The open project document — opaque; field access happens in the FFI.
foreign import data ProjectDoc :: Type

-- | The doc's `repo` frontmatter; null when absent.
foreign import repoOfImpl :: ProjectDoc -> Nullable String

-- | The doc's `url` frontmatter; null when absent.
foreign import urlOfImpl :: ProjectDoc -> Nullable String

-- | The doc's `references` frontmatter; `[]` when absent.
foreign import referencesOfImpl :: ProjectDoc -> Array String

-- | The lesson title at this path in the build-time notes index; null
-- | when unindexed.
foreign import notesTitleImpl :: String -> Nullable String

-- | The URL's pathname; null when the string doesn't parse as a URL.
foreign import pathnameOfImpl :: String -> Nullable String

-- | One rendered reference entry; `notes` marks links into the notes
-- | site.
type Reference =
  { -- | The link target (PDF urls gain a fit-to-page viewer fragment).
    href :: String
  , -- | The display title.
    title :: String
  , -- | Whether the link points into the notes site.
    notes :: Boolean
  }

type ReferencesBindings =
  { -- | The rendered list: repo and live link lead, notes links follow.
    references :: Computed (Array Reference)
  }

-- | Titles for the notes site's subject-index pages, which carry no
-- | frontmatter of their own.
subjectLabel :: String -> Maybe String
subjectLabel = case _ of
  "/algorithms" -> Just "Algorithms"
  "/computer-architecture" -> Just "Computer Architecture"
  "/artificial-intelligence" -> Just "Artificial Intelligence"
  "/natural-language-processing" -> Just "Natural Language Processing"
  "/linear-algebra" -> Just "Linear Algebra"
  "/deep-learning" -> Just "Deep Learning"
  _ -> Nothing

-- | Name a project link by what it actually is, not a generic "live
-- | site".
urlTitle :: String -> String
urlTitle url
  | contains (Pattern "huggingface.co") url = "Dataset"
  | contains (Pattern "leetcode.com") url = "LeetCode profile"
  | contains (Pattern "/papers/dujs/") url = "Published paper"
  | isPdf url = "Final paper"
  | contains (Pattern "drive.google.com") url = "Publication"
  | contains (Pattern "/docs") url = "Documentation"
  | hasArticlePath url = "Article"
  | otherwise = "Live site"

isPdf :: String -> Boolean
isPdf url = isJust (stripSuffix (Pattern ".pdf") url)

-- | `/amittai\.space\/./` — some occurrence of "amittai.space/"
-- | followed by a (non-newline) character.
hasArticlePath :: String -> Boolean
hasArticlePath url = go 0
  where
  needle = "amittai.space/"
  go from = case CU.indexOf' (Pattern needle) from url of
    Nothing -> false
    Just i -> case CU.charAt (i + CU.length needle) url of
      Just c | c /= '\n' -> true
      _ -> go (i + 1)

-- | `.replace(/\/+$/, "")`.
stripTrailingSlashes :: String -> String
stripTrailingSlashes path = case stripSuffix (Pattern "/") path of
  Just rest -> stripTrailingSlashes rest
  Nothing -> path

-- | JS string truthiness: empty strings drop out.
nonEmpty :: Maybe String -> Maybe String
nonEmpty = case _ of
  Just "" -> Nothing
  other -> other

-- | Build the reference list for the open project document; the
-- | computed re-derives whenever `selected` changes.
setup :: Ref (Nullable ProjectDoc) -> Effect ReferencesBindings
setup selected = do
  projectRefs <- computed do
    mDoc <- toMaybe <$> read selected
    let
      repo = nonEmpty (mDoc >>= repoOfImpl >>> toMaybe)
      url = nonEmpty (mDoc >>= urlOfImpl >>> toMaybe)
    pure $ catMaybes
      [ repo <#> \href -> { href, title: "Project repository", notes: false }
      , url <#> \raw ->
          { href: if isPdf raw then raw <> "#view=FitV&zoom=page-fit" else raw
          , title: urlTitle raw
          , notes: false
          }
      ]

  references <- computed do
    lead <- read projectRefs
    mDoc <- toMaybe <$> read selected
    let
      entries = maybe [] referencesOfImpl mDoc <#> \href ->
        let
          path = stripTrailingSlashes (fromMaybe href (toMaybe (pathnameOfImpl href)))
        in
          case toMaybe (notesTitleImpl path) of
            Just title -> { href, title, notes: true }
            Nothing -> { href, title: fromMaybe path (subjectLabel path), notes: true }
    pure (lead <> entries)

  pure { references }
