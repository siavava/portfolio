-- | ## SmokeViz
-- |
-- | The setup composable behind `SmokeViz.vue` — a miniature Eulerian smoke
-- | solver with toggleable vorticity confinement. Orchestration (controls,
-- | the confine watch, note text, frame loop, lifecycle, and the theme
-- | color parsing in `smokeColor`) is PureScript;
-- | the grid solver itself stays in the FFI as a documented numeric kernel:
-- | its state is six `Float32Array` fields plus canvas/`ImageData` handles,
-- | and the advection/projection sweeps must run at frame rate over 2 592
-- | cells — see `app/ffi/components/smoke-viz.ts`.
module App.Components.SmokeViz
  ( CanvasEl
  , SmokeArgs
  , SmokeBindings
  , confineNote
  , setup
  , smokeColor
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Array (index)
import Data.Array.NonEmpty (toArray)
import Data.Function.Uncurried (Fn2, mkFn2)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.String.CodeUnits as CodeUnits
import Data.String.Regex (Regex, match)
import Data.String.Regex.Flags (global)
import Data.String.Regex.Unsafe (unsafeRegex)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, runEffectFn1, runEffectFn2, runEffectFn3)
import Vue (Ref, read, ref, watchRef, write)

-- | The `<canvas>` element behind the plume.
foreign import data CanvasEl :: Type

foreign import data SmokeSim :: Type

foreign import newSmokeSimImpl :: Effect SmokeSim

foreign import initCanvasImpl
  :: EffectFn3 SmokeSim CanvasEl (Fn2 String (Array Number) (Array Number)) Unit

foreign import parseHexImpl :: String -> Number

foreign import jsNumberImpl :: String -> Number

foreign import stepImpl :: EffectFn2 SmokeSim Boolean Unit

foreign import renderImpl :: EffectFn1 SmokeSim Unit

foreign import hardResetImpl :: EffectFn1 SmokeSim Unit

foreign import rafLoopImpl :: EffectFn1 (Effect Unit) (Effect Unit)

decimalRun :: Regex
decimalRun = unsafeRegex "(\\d+(?:\\.\\d+)?)" global

-- | Reads a computed CSS color into an `[r, g, b]` triple, or returns the
-- | fallback untouched. A leading `#` takes the hex path: three digits
-- | double up (`#fff` → `ffffff`), then the first three byte pairs go
-- | through `parseInt(_, 16)` — so short or malformed hex yields NaN
-- | channels rather than the fallback, exactly as the original did.
-- | Anything else takes its first three decimal runs as channels
-- | verbatim, whatever the color space (`oklch(0.5 0.1 200)` reads as
-- | `[0.5, 0.1, 200]`); fewer than three runs keeps the fallback.
smokeColor :: String -> Array Number -> Array Number
smokeColor s fallback
  | CodeUnits.take 1 s == "#" =
      let
        h = CodeUnits.drop 1 s
        n =
          if CodeUnits.length h == 3 then
            CodeUnits.fromCharArray (CodeUnits.toCharArray h >>= \c -> [ c, c ])
          else h
      in
        [ parseHexImpl (CodeUnits.slice 0 2 n)
        , parseHexImpl (CodeUnits.slice 2 4 n)
        , parseHexImpl (CodeUnits.slice 4 6 n)
        ]
  | otherwise = fromMaybe fallback do
      runs <- toArray <$> match decimalRun s
      r <- join (index runs 0)
      g <- join (index runs 1)
      b <- join (index runs 2)
      pure (map jsNumberImpl [ r, g, b ])

-- | The note after a reset: what the confinement toggle does to the
-- | plume.
confineNote :: Boolean -> String
confineNote on =
  if on then "vorticity confinement on — the plume keeps its curl"
  else "vorticity confinement off — small-scale swirl damps away"

type SmokeArgs =
  { -- | Template ref to the `<canvas>` the sim binds to after first paint.
    canvas :: Ref (Nullable CanvasEl)
  }

type SmokeBindings =
  { -- | Vorticity-confinement toggle, bound to the select.
    confine :: Ref Boolean
  -- | One-line status/explanation under the canvas.
  , note :: Ref String
  -- | Zero the fields and refresh the note for the current toggle.
  , reset :: Effect Unit
  }

-- | Wires the smoke sim to the canvas after first paint and starts the
-- | frame loop (one solver step + render per rAF). Binds the confine
-- | toggle, the note line, and a reset action; toggling confine resets
-- | the field so the two regimes start alike.
setup :: SmokeArgs -> Effect SmokeBindings
setup args = do
  confine <- ref true
  note <- ref "bottom-center emitter feeding a rising plume"
  sim <- newSmokeSimImpl

  let
    reset = do
      runEffectFn1 hardResetImpl sim
      on <- read confine
      write note (confineNote on)

    tick = do
      on <- read confine
      runEffectFn2 stepImpl sim on
      runEffectFn1 renderImpl sim

  _ <- watchRef confine \_ -> reset

  resume <- runEffectFn1 rafLoopImpl tick
  useAfterPaint do
    element <- toMaybe <$> read args.canvas
    case element of
      Nothing -> pure unit
      Just el -> do
        runEffectFn3 initCanvasImpl sim el (mkFn2 smokeColor)
        reset
        resume

  pure { confine, note, reset }
