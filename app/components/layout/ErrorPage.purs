-- | ## ErrorPage
-- |
-- | The setup composable behind `app/error.vue`, the themed stand-in for
-- | Nuxt's default error page: a stray node that has drifted off the
-- | interest map. The orbital rings ripple out one after another on motion-v
-- | springs, the spokes reach just past the outer ring as it grows, and once
-- | the last ring settles the stray node fades in at a random spot between
-- | the rings. The module lives under `components/layout/` because neither
-- | the app root nor `pages/` may hold one. The SFC keeps the prop macro,
-- | the route and color-mode handles, and the head call plus one call here;
-- | the page's words and the scene's geometry are read from the bindings.
module App.Components.ErrorPage
  ( ErrorPageArgs
  , ErrorPageBindings
  , Point
  , Spoke
  , SpringControls
  , StatusCode
  , errorDetailFor
  , errorHeadingFor
  , errorStatusWordFor
  , errorModeClassFor
  , ringTargets
  , roundTenth
  , setup
  , spokeTip
  , spokes
  , strayAt
  ) where

import Prelude

import App.Utils.JsMath (indexOrZero)
import Data.Array (length, snoc)
import Data.Foldable (traverse_)
import Data.FoldableWithIndex (forWithIndex_)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Number (cos, pi, sin)
import Data.Number (fromString) as Number
import Data.Number.Format (fixed, toStringWith)
import Effect (Effect)
import Effect.Random (random)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn3
  , EffectFn6
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn3
  , runEffectFn6
  )
import Vue (Computed, Ref, computed, onBeforeUnmount, onMounted, read, ref, write)

-- | A running motion-v spring's controls — only stopped. @ts { stop: () => void }
foreign import data SpringControls :: Type

foreign import springImpl
  :: EffectFn6 Number Number Number Number (EffectFn1 Number Unit) (Effect Unit) SpringControls

foreign import stopSpringImpl :: EffectFn1 SpringControls Unit

foreign import setRingRadiusImpl :: EffectFn3 (Ref (Array Number)) Int Number Unit

-- | The error's HTTP status code as Nuxt hands it over — a number, though
-- | the type allows it to be missing. @ts number | undefined
foreign import data StatusCode :: Type

foreign import codeOfImpl :: StatusCode -> Nullable Int

foreign import codeTextImpl :: StatusCode -> String

-- | A point in the scene's 440 × 220 viewBox.
type Point = { x :: Number, y :: Number }

-- | One spoke fanning out from the scene's center: its angle in degrees
-- | (also its key) and the unit vector along it, y pointing up.
type Spoke = { deg :: Int, ux :: Number, uy :: Number }

type ErrorPageArgs =
  { -- | Reads the current color-mode value ("dark"/"light").
    colorModeValue :: Effect String
  -- | Reads the error's HTTP status code.
  , statusCode :: Effect StatusCode
  -- | Reads the error's status message, null when it carries none.
  , statusMessage :: Effect (Nullable String)
  }

type ErrorPageBindings =
  { -- | Page class: "dark-mode" or "light-mode".
    mode :: Computed String
  -- | Whether the error is a 404 — the page then names the missing path
  -- | instead of the error message.
  , notFound :: Computed Boolean
  -- | The rings' resting radii, innermost first; the template draws one
  -- | circle per entry.
  , rings :: Array Number
  -- | The spokes' angles and unit vectors.
  , spokes :: Array Spoke
  -- | The rings' current radii as their springs run; a ring whose spring
  -- | has not started has no entry yet.
  , ringRadii :: Ref (Array Number)
  -- | True once the outer ring has settled — fades the stray node in.
  , placed :: Ref Boolean
  -- | Where the stray node sits; scattered anew on every mount.
  , stray :: Ref Point
  -- | The word after the status code: "not found" or "error".
  , statusWord :: Computed String
  -- | The page's heading.
  , heading :: Computed String
  -- | The error's message, or a stock line when it has none.
  , detail :: Computed String
  -- | A ring's current radius by its index, 0 until its spring starts —
  -- | a tracked read, so the circle redraws as the spring runs.
  , ringRadius :: EffectFn1 Int Number
  -- | Where a spoke ends: just past the outer ring as it currently is.
  , spokeEnd :: EffectFn1 Spoke Point
  -- | The document title, fed to `useHead`.
  , title :: String
  }

-- | The rings' resting radii, innermost first.
ringTargets :: Array Number
ringTargets = [ 66.0, 126.0, 186.0 ]

-- | The spokes across the upper half-disc, each with its unit vector.
spokes :: Array Spoke
spokes = map spoke [ 16, 38, 64, 88, 112, 138, 164 ]
  where
  spoke deg =
    let
      angle = toNumber deg * pi / 180.0
    in
      { deg, ux: cos angle, uy: sin angle }

-- | Where a spoke ends for a given outer-ring radius: a tenth past it, so
-- | the spokes always reach beyond the rings.
spokeTip :: Number -> Spoke -> Point
spokeTip outer spoke =
  { x: 220.0 + spoke.ux * outer * 1.1
  , y: 220.0 - spoke.uy * outer * 1.1
  }

-- | The page's heading: lost for a 404, broken for anything else.
errorHeadingFor :: Boolean -> String
errorHeadingFor notFound = if notFound then "Off the map." else "Something broke."

-- | The word the meta line puts after the status code.
errorStatusWordFor :: Boolean -> String
errorStatusWordFor notFound = if notFound then "not found" else "error"

-- | The error's message, falling back to a stock line when it is missing
-- | or empty — an empty message says nothing either.
errorDetailFor :: Nullable String -> String
errorDetailFor message = case toMaybe message of
  Just text | text /= "" -> text
  _ -> "An unexpected error occurred."

-- | Rounds to one decimal the way `+n.toFixed(1)` does, so the node's
-- | coordinates stay short in the markup.
roundTenth :: Number -> Number
roundTenth n = fromMaybe n (Number.fromString (toStringWith (fixed 1) n))

-- | The page's class for the color mode: dark only when the mode says so.
errorModeClassFor :: String -> String
errorModeClassFor value = if value == "dark" then "dark-mode" else "light-mode"

-- | Where the stray node sits for two rolls in [0, 1): `spin` picks its
-- | angle across the upper half-disc, 15° to 165°, and `reach` its
-- | distance from the center, from 84 (clear of the inner ring) out to
-- | 200 — held in near the vertical so the node stays inside the
-- | viewBox's top edge (y ≥ 25). Coordinates are rounded to a tenth.
strayAt :: Number -> Number -> Point
strayAt spin reach =
  let
    theta = (15.0 + spin * 150.0) * pi / 180.0
    rMin = 84.0
    rMax = min 200.0 (195.0 / sin theta)
    radius = rMin + reach * (rMax - rMin)
  in
    { x: roundTenth (220.0 + radius * cos theta)
    , y: roundTenth (220.0 - radius * sin theta)
    }

ringStagger :: Int
ringStagger = 110

-- | Wires the error scene: the color-mode class, the 404 check, the ring
-- | wave on mount with the stray node scattered at a random angle and
-- | distance, and cleanup of any springs and timers still pending when the
-- | page goes away.
setup :: ErrorPageArgs -> Effect ErrorPageBindings
setup args = do
  mode <- computed (errorModeClassFor <$> args.colorModeValue)

  notFound <- computed ((_ == Just 404) <<< toMaybe <<< codeOfImpl <$> args.statusCode)

  code <- codeTextImpl <$> args.statusCode

  statusWord <- computed (errorStatusWordFor <$> read notFound)
  heading <- computed (errorHeadingFor <$> read notFound)
  detail <- computed (errorDetailFor <$> args.statusMessage)

  ringRadii <- ref ([] :: Array Number)
  placed <- ref false
  stray <- ref { x: 118.0, y: 86.0 }
  waveControls <- Ref.new ([] :: Array SpringControls)
  waveTimers <- Ref.new ([] :: Array TimeoutId)

  let
    scatterStray = do
      spin <- random
      reach <- random
      write stray (strayAt spin reach)

    radiusAt i = flip indexOrZero i <$> read ringRadii

    waveRings = forWithIndex_ ringTargets \index target -> do
      pending <- setTimeout (index * ringStagger) do
        controls <- runEffectFn6 springImpl 0.0 target 0.4 0.3
          ( mkEffectFn1 \latest ->
              runEffectFn3 setRingRadiusImpl ringRadii index (max 0.0 latest)
          )
          (when (index == length ringTargets - 1) (write placed true))
        Ref.modify_ (flip snoc controls) waveControls
      Ref.modify_ (flip snoc pending) waveTimers

  onMounted do
    scatterStray
    waveRings

  onBeforeUnmount do
    Ref.read waveControls >>= traverse_ (runEffectFn1 stopSpringImpl)
    Ref.read waveTimers >>= traverse_ clearTimeout

  pure
    { mode
    , notFound
    , rings: ringTargets
    , spokes
    , ringRadii
    , placed
    , stray
    , statusWord
    , heading
    , detail
    , ringRadius: mkEffectFn1 radiusAt
    , spokeEnd: mkEffectFn1 \spoke -> flip spokeTip spoke <$> radiusAt 2
    , title: code <> " · Amittai Siavava"
    }
