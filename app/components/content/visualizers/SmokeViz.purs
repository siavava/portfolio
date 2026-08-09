-- | ## SmokeViz
-- |
-- | The setup composable behind `SmokeViz.vue` — a miniature Eulerian smoke
-- | solver with toggleable vorticity confinement. Orchestration (controls,
-- | the confine watch, note text, frame loop, and lifecycle) is PureScript;
-- | the grid solver itself stays in the FFI as a documented numeric kernel:
-- | its state is six `Float32Array` fields plus canvas/`ImageData` handles,
-- | and the advection/projection sweeps must run at frame rate over 2 592
-- | cells — see `app/ffi/components/smoke-viz.ts`.
module App.Components.SmokeViz
  ( CanvasEl
  , SmokeArgs
  , SmokeBindings
  , setup
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Vue (Ref, read, ref, watchRef, write)

-- | The `<canvas>` element behind the plume.
foreign import data CanvasEl :: Type

-- | The FFI kernel's grid state (velocity, density, pressure fields and
-- | canvas handles).
foreign import data SmokeSim :: Type

-- | Fresh zeroed grid state; the theme colors stay at their defaults
-- | until `initCanvasImpl` reads them off the canvas.
foreign import newSmokeSimImpl :: Effect SmokeSim

-- | Bind the sim to the mounted canvas: size it, read the theme colors
-- | from computed style, and build the offscreen grid buffer.
foreign import initCanvasImpl :: EffectFn2 SmokeSim CanvasEl Unit

-- | One solver step — inject at the emitter, buoyancy, vorticity
-- | confinement when the Boolean is on, then the project/advect/project
-- | sweeps and dissipation. Hard-resets itself on numeric blow-up.
foreign import stepImpl :: EffectFn2 SmokeSim Boolean Unit

-- | Paint the density field into the offscreen `ImageData`, then scale
-- | it onto the visible canvas.
foreign import renderImpl :: EffectFn1 SmokeSim Unit

-- | Zero every field array; the canvas binding stays.
foreign import hardResetImpl :: EffectFn1 SmokeSim Unit

-- | Wraps `useRafFn(fn, { immediate: false })`; returns the resume Effect.
foreign import rafLoopImpl :: EffectFn1 (Effect Unit) (Effect Unit)

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
      write note
        ( if on then "vorticity confinement on — the plume keeps its curl"
          else "vorticity confinement off — small-scale swirl damps away"
        )

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
        runEffectFn2 initCanvasImpl sim el
        reset
        resume

  pure { confine, note, reset }
