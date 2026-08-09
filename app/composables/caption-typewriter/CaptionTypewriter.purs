-- | ## CaptionTypewriter
-- |
-- | The pure geometry core of `useCaptionTypewriter`: merging measured
-- | character boxes into visual lines, and building the clip-path polygon
-- | that reveals the first `shown` characters. DOM measurement, watches,
-- | and the rAF loop stay in the TypeScript composable.
module App.Composables.CaptionTypewriter
  ( Box
  , linesOf
  , reveal
  , revealJs
  ) where

import Prelude

import Data.Array (findIndex, index, last, length, reverse, slice, snoc)
import Data.Foldable (foldl)
import Data.Function.Uncurried (Fn3, mkFn3)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (joinWith)

-- | A measured rectangle relative to the caption's box.
type Box = { left :: Number, right :: Number, top :: Number, bottom :: Number }

foreign import showNumberImpl :: Number -> String

-- | Merge per-character boxes into one box per visual line: a unit whose
-- | top sits above the running line's midpoint joins it, else starts a
-- | new line.
linesOf :: Array Box -> Array Box
linesOf = foldl step []
  where
  step lines unit' = case last lines of
    Just line | unit'.top < line.top + (unit'.bottom - unit'.top) * 0.5 ->
      slice 0 (length lines - 1) lines `snoc`
        { left: min line.left unit'.left
        , right: max line.right unit'.right
        , top: min line.top unit'.top
        , bottom: max line.bottom unit'.bottom
        }
    _ -> snoc lines unit'

-- | The clip-path polygon revealing the first `shown` character boxes:
-- | every full line above the cursor, plus the current line up to the
-- | last visible character's right edge.
reveal :: Array Box -> Array Box -> Int -> String
reveal units lines shown =
  if shown <= 0 then "polygon(0 0, 0 0, 0 0)"
  else case index units (shown - 1) of
    Nothing -> "polygon(0 0, 0 0, 0 0)"
    Just lastUnit ->
      let
        current = fromMaybe (length lines - 1)
          ( findIndex
              (\line -> lastUnit.top < line.bottom - 0.5 && lastUnit.bottom > line.top + 0.5)
              lines
          )
        currentLine = fromMaybe lastUnit (index lines current)
        rects = slice 0 current lines `snoc`
          { left: currentLine.left
          , right: lastUnit.right
          , top: currentLine.top
          , bottom: currentLine.bottom
          }
        px n = showNumberImpl n <> "px"
        firstRect = fromMaybe lastUnit (index rects 0)
        forward = rects >>= \rect ->
          [ px rect.right <> " " <> px rect.top, px rect.right <> " " <> px rect.bottom ]
        backward = reverse rects >>= \rect ->
          [ px rect.left <> " " <> px rect.bottom, px rect.left <> " " <> px rect.top ]
        points = [ px firstRect.left <> " " <> px firstRect.top ] <> forward <> backward
      in
        "polygon(" <> joinWith ", " points <> ")"

revealJs :: Fn3 (Array Box) (Array Box) Int String
revealJs = mkFn3 reveal
