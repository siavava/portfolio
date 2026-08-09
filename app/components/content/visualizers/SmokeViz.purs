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
  , useSmokeViz
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue (Ref, read, ref, watchRef, write)

-- | The `<canvas>` element behind the plume.
foreign import data CanvasEl :: Type

-- | The FFI kernel's grid state (velocity, density, pressure fields and
-- | canvas handles).
foreign import data SmokeSim :: Type

foreign import newSmokeSimImpl :: Effect SmokeSim
foreign import initCanvasImpl :: EffectFn2 SmokeSim CanvasEl Unit
foreign import stepImpl :: EffectFn2 SmokeSim Boolean Unit
foreign import renderImpl :: EffectFn1 SmokeSim Unit
foreign import hardResetImpl :: EffectFn1 SmokeSim Unit
foreign import rafLoopImpl :: EffectFn1 (Effect Unit) (Effect Unit)

type SmokeArgs = { canvas :: Ref (Nullable CanvasEl) }

type SmokeBindings =
  { confine :: Ref Boolean
  , note :: Ref String
  , reset :: Effect Unit
  }

useSmokeViz :: EffectFn1 SmokeArgs SmokeBindings
useSmokeViz = mkEffectFn1 setup

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
  runEffectFn1 useAfterPaint do
    element <- toMaybe <$> read args.canvas
    case element of
      Nothing -> pure unit
      Just el -> do
        runEffectFn2 initCanvasImpl sim el
        reset
        resume

  pure { confine, note, reset }
