-- | ## Fences
-- |
-- | Build-time core of the content pipeline's first pass: rewrites code-fence
-- | language aliases (` ```py `, ` ```c++ `, ` ```f# `) to the canonical
-- | Shiki grammar id the content highlighter loads (` ```python `). Without
-- | it an aliased fence is unknown to the highlighter and falls back to
-- | unstyled plain text. The fence info string (filename, `{line}`
-- | highlight meta) is kept, and languages with no alias (`algorithm`,
-- | `tikz`, ids that are already canonical) pass through untouched.
-- | `transformers/index.ts` loads it lazily from `applyTransforms`, the
-- | entry the `content:file:beforeParse` hook calls. @ts-internal
module App.Transformers.Fences
  ( aliasOf
  , normalize
  ) where

import Prelude

import Data.Maybe (Maybe(..), maybe)
import Data.String.Regex (Regex, replace')
import Data.String.Regex.Flags (global, multiline)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | The canonical Shiki grammar id for a fence-language alias, or `Nothing`
-- | when the language is not an alias.
aliasOf :: String -> Maybe String
aliasOf = case _ of
  "py" -> Just "python"
  "py3" -> Just "python"
  "js" -> Just "javascript"
  "cjs" -> Just "javascript"
  "mjs" -> Just "javascript"
  "node" -> Just "javascript"
  "ts" -> Just "typescript"
  "rs" -> Just "rust"
  "rb" -> Just "ruby"
  "hs" -> Just "haskell"
  "md" -> Just "markdown"
  "mkd" -> Just "markdown"
  "sh" -> Just "shell"
  "bash" -> Just "shell"
  "zsh" -> Just "shell"
  "console" -> Just "shell"
  "shellscript" -> Just "shell"
  "c++" -> Just "cpp"
  "cc" -> Just "cpp"
  "cxx" -> Just "cpp"
  "hpp" -> Just "cpp"
  "yml" -> Just "yaml"
  "gql" -> Just "graphql"
  "fs" -> Just "fsharp"
  "f#" -> Just "fsharp"
  "golang" -> Just "go"
  "tex" -> Just "latex"
  "htm" -> Just "html"
  "jl" -> Just "julia"
  _ -> Nothing

-- | `constructor` mirrors the TS original's `Object.prototype` lookup bug, kept for parity.
canonicalOf :: String -> Maybe String
canonicalOf = case _ of
  "constructor" -> Just "function Object() { [native code] }"
  lang -> aliasOf lang

fenceOpening :: Regex
fenceOpening = unsafeRegex "^([ \\t]*`{3,})([a-z0-9+#-]+)" (multiline <> global)

-- | Rewrites every aliased fence language in a markdown body to its
-- | canonical grammar id; everything else in the body is kept as is.
normalize :: String -> String
normalize = replace' fenceOpening rewrite
  where
  rewrite match = case _ of
    [ Just fence, Just lang ] -> maybe match (fence <> _) (canonicalOf lang)
    _ -> match
