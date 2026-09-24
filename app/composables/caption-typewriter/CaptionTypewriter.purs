-- | ## CaptionTypewriter
-- |
-- | Types a figure caption out as it opens by sweeping an animated
-- | clip-path mask across the plain text, letter by letter. The caption
-- | stays a single text run, so it shapes and wraps exactly like the
-- | hover pop-up's caption — splitting it into per-character spans
-- | drifts the layout a hair narrower and flips words at the line
-- | boundary. Every time the open state flips truthy the caption is
-- | re-measured and retyped, with `onOpen` running first (e.g. to size
-- | the figure). Honours `prefers-reduced-motion`.
-- |
-- | The geometry — merging measured character boxes into visual lines
-- | and building the reveal polygon — is pure and lives here, as does
-- | the frame loop; the range measurement, the style write, and the
-- | timestamped rAF sit behind the FFI edge.
module App.Composables.CaptionTypewriter
  ( Box
  , DomElement
  , OpenState
  , charsPerStep
  , linesOf
  , reveal
  , useCaptionTypewriter
  ) where

import Prelude

import Data.Array (findIndex, index, last, length, null, reverse, slice, snoc)
import Data.Foldable (foldl, for_)
import Data.Int (ceil, toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Number.Format (toString)
import Data.String (joinWith)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn3
  , runEffectFn1
  , runEffectFn2
  )
import Vue (Ref, onBeforeUnmount, read)

-- | The caption element — opaque here; only the FFI touches it.
-- | @ts HTMLElement
foreign import data DomElement :: Type

-- | Whatever the open-state getter returns; only its truthiness counts,
-- | and the FFI watch tests it. @ts unknown
foreign import data OpenState :: Type

-- | A measured rectangle relative to the caption's box.
type Box = { left :: Number, right :: Number, top :: Number, bottom :: Number }

foreign import measureImpl :: EffectFn1 DomElement (Array Box)

foreign import setClipPathImpl :: EffectFn2 DomElement String Unit

foreign import reducedMotionImpl :: Effect Boolean

foreign import requestFrameImpl :: EffectFn1 (EffectFn1 Number Unit) Int

foreign import cancelFrameImpl :: EffectFn1 Int Unit

foreign import watchOpenPostImpl :: EffectFn2 (Effect OpenState) (EffectFn1 Boolean Unit) Unit

foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

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
  if shown <= 0 then hidden
  else case index units (shown - 1) of
    Nothing -> hidden
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
        px n = toString n <> "px"
        firstRect = fromMaybe lastUnit (index rects 0)
        forward = rects >>= \rect ->
          [ px rect.right <> " " <> px rect.top, px rect.right <> " " <> px rect.bottom ]
        backward = reverse rects >>= \rect ->
          [ px rect.left <> " " <> px rect.bottom, px rect.left <> " " <> px rect.top ]
        points = [ px firstRect.left <> " " <> px firstRect.top ] <> forward <> backward
      in
        "polygon(" <> joinWith ", " points <> ")"

-- | How many characters each ~16ms step reveals for a caption of `n`:
-- | about 1/62 of them, at least one, so any caption types out in
-- | roughly a second.
charsPerStep :: Int -> Int
charsPerStep n = max 1 (ceil (toNumber n / 62.0))

hidden :: String
hidden = "polygon(0 0, 0 0, 0 0)"

-- | Type the caption held in `cap` out whenever `active` turns truthy
-- | (after the DOM settles, running `onOpen` first), and unmask it
-- | whenever `active` turns falsy or the component unmounts. Reveals
-- | about 1/62 of the characters per ~16ms step, so any caption types
-- | out in roughly a second. `start`/`stop` are returned for manual
-- | control.
useCaptionTypewriter
  :: EffectFn3
       (Ref (Nullable DomElement))
       (Effect OpenState)
       (Nullable (Effect Unit))
       { start :: Effect Unit, stop :: Effect Unit }
useCaptionTypewriter = mkEffectFn3 \cap active onOpen -> do
  frame <- Ref.new 0

  let
    setClip el value = runEffectFn2 setClipPathImpl el value

    schedule step = do
      handle <- runEffectFn1 requestFrameImpl (mkEffectFn1 step)
      Ref.write handle frame

    stop = do
      handle <- Ref.read frame
      when (handle /= 0) do
        runEffectFn1 cancelFrameImpl handle
        Ref.write 0 frame
      el <- toMaybe <$> read cap
      for_ el \el' -> setClip el' ""

    start = do
      stop
      el <- toMaybe <$> read cap
      for_ el \el' -> do
        setClip el' hidden
        units <- runEffectFn1 measureImpl el'
        if null units then setClip el' ""
        else do
          let lines = linesOf units
          reduced <- reducedMotionImpl
          if reduced then setClip el' ""
          else animate el' units lines

    animate el units lines = do
      let
        n = length units
        perFrame = charsPerStep n
      shown <- Ref.new 0
      previous <- Ref.new 0.0
      let
        tick now = do
          before <- Ref.read previous
          since <- if before == 0.0 then Ref.write now previous $> now else pure before
          when (now - since >= 16.0) do
            Ref.write now previous
            revealed <- Ref.modify (\s -> min n (s + perFrame)) shown
            setClip el (reveal units lines revealed)
          count <- Ref.read shown
          if count < n then schedule tick
          else do
            setClip el ""
            Ref.write 0 frame
      schedule tick

  runEffectFn2 watchOpenPostImpl active $ mkEffectFn1 \open ->
    if open then runEffectFn1 nextTickImpl (for_ (toMaybe onOpen) identity *> start)
    else stop

  onBeforeUnmount stop

  pure { start, stop }
