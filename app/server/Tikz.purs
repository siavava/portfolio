-- | ## Tikz
-- |
-- | Pure core behind `server/api/tikz/[hash].get.ts`, which serves a
-- | build-rendered TikZ figure by content hash: sanitizes the route param
-- | to lowercase hex, names the cache file, strips the prerendered
-- | `<figure>` wrapper, and rewrites the SVG root's fixed `width`/`height`
-- | attributes into a responsive inline style. The filesystem and h3
-- | edges stay in the shell.
module App.Server.Tikz
  ( cacheFileName
  , sanitizeHash
  , tikzResponseHtml
  ) where

import Prelude

import Data.Array.NonEmpty as NEA
import Data.Maybe (Maybe(..))
import Data.String.Regex (Regex, match, replace, replace')
import Data.String.Regex.Flags (global, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | `(param ?? "").replace(/[^a-f0-9]/g, "")` — the route param reduced
-- | to lowercase hex.
sanitizeHash :: String -> String
sanitizeHash = replace nonHexChars ""

-- | `<hash>.html` — the figure's file name under `.cache/tikz`.
cacheFileName :: String -> String
cacheFileName hash = hash <> ".html"

-- | The whole response body: strip the `<figure>` wrapper the transformer
-- | rendered, then make the SVG root responsive.
tikzResponseHtml :: String -> String
tikzResponseHtml = stripFigureWrapper >>> responsiveSvgRoot

nonHexChars :: Regex
nonHexChars = unsafeRegex "[^a-f0-9]" global

figureOpen :: Regex
figureOpen = unsafeRegex "^\\s*<figure[^>]*>" noFlags

figureClose :: Regex
figureClose = unsafeRegex "</figure>\\s*$" noFlags

stripFigureWrapper :: String -> String
stripFigureWrapper raw = replace figureClose "" (replace figureOpen "" raw)

svgOpenTag :: Regex
svgOpenTag = unsafeRegex "<svg\\b[^>]*>" noFlags

widthAttr :: Regex
widthAttr = unsafeRegex "\\bwidth=\"([\\d.]+)\"" noFlags

sizeAttrs :: Regex
sizeAttrs = unsafeRegex "\\s(?:width|height)=\"[\\d.]+\"" global

styleAttrCapture :: Regex
styleAttrCapture = unsafeRegex "\\sstyle=\"([^\"]*)\"" noFlags

styleAttrPlain :: Regex
styleAttrPlain = unsafeRegex "\\sstyle=\"[^\"]*\"" noFlags

trailingSemi :: Regex
trailingSemi = unsafeRegex "\\s*;?\\s*$" noFlags

svgBare :: Regex
svgBare = unsafeRegex "<svg\\b" noFlags

-- | Rewrite the first `<svg …>` tag's fixed `width`/`height` attributes
-- | into `width:100%;max-width:<w>px;height:auto`, appended to any
-- | existing inline style (normalized to end in one `;`).
responsiveSvgRoot :: String -> String
responsiveSvgRoot = replace' svgOpenTag \tag _ -> retag tag
  where
  retag tag = case firstGroup widthAttr tag of
    Nothing -> tag
    Just width ->
      let
        decl = "width:100%;max-width:" <> width <> "px;height:auto"
        out = replace sizeAttrs "" tag
      in
        case firstGroup styleAttrCapture out of
          Just prev ->
            replace styleAttrPlain (" style=\"" <> replace trailingSemi ";" prev <> decl <> "\"")
              out
          Nothing -> replace svgBare ("<svg style=\"" <> decl <> "\"") out

-- | The first capture group of the first match, `Nothing` when unmatched.
firstGroup :: Regex -> String -> Maybe String
firstGroup regex s = join (match regex s >>= flip NEA.index 1)
