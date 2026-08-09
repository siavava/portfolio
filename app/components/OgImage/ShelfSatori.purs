-- | ## ShelfSatori
-- |
-- | The layout math behind `Shelf.satori.vue`, the build-time OG card
-- | rendered through satori (nuxt-og-image) — no window, no lifecycle.
-- | Seeded spine geometry (FNV-style uint32 hashing, mirrored bit-exact
-- | via an `imul` FFI prim plus unsigned views), the shelf fill loop, the
-- | description clamp, and every static style record are pure PureScript;
-- | the FFI carries only JS string/whitespace semantics and the
-- | conditional-spread style assembly.
module App.Components.ShelfSatori
  ( Book
  , SatoriArgs
  , SatoriBindings
  , StyleMap
  , useShelfSatori
  ) where

import Prelude

import Data.Array as Array
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int (floor, round, toNumber) as Int
import Data.Int.Bits (xor, zshr)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, toNullable)
import Data.Number (floor)
import Data.Number (max, pow, remainder, round) as Number
import Data.Number.Format (toString)
import Data.String.CodeUnits (length, take) as CodeUnits
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue (Computed, computed)

-- | An assembled `:style` object (string/number CSS values). @ts import("vue").CSSProperties
foreign import data StyleMap :: Type

foreign import imulImpl :: Fn2 Int Int Int
foreign import normalizeDescriptionImpl :: String -> String
foreign import trimEndImpl :: String -> String
foreign import mkBookStyleImpl
  :: Fn2
       { display :: String
       , flexShrink :: Number
       , width :: String
       , height :: String
       , marginRight :: String
       , backgroundColor :: String
       , border :: String
       , borderTopLeftRadius :: String
       , borderTopRightRadius :: String
       }
       (Nullable { transform :: String, transformOrigin :: String })
       StyleMap

type Book =
  { width :: Int, heightPct :: Int, gap :: Int, tilt :: Int, arc :: Number, lit :: Boolean }

type SatoriArgs =
  { index :: Effect Int
  , total :: Effect Int
  , description :: Effect String
  }

type SatoriBindings =
  { books :: Computed (Array Book)
  , clampedDescription :: Computed String
  , bookStyle :: Book -> StyleMap
  , frame ::
      { width :: String
      , height :: String
      , display :: String
      , flexDirection :: String
      , justifyContent :: String
      , padding :: String
      , backgroundColor :: String
      , fontFamily :: String
      }
  , card ::
      { display :: String
      , flexDirection :: String
      , padding :: String
      , backgroundColor :: String
      , border :: String
      , borderRadius :: String
      }
  , kickerStyle :: { fontSize :: String, color :: String, letterSpacing :: String }
  , titleStyle ::
      { marginTop :: String
      , fontSize :: String
      , lineHeight :: Number
      , color :: String
      , maxWidth :: String
      , maxHeight :: String
      , overflow :: String
      }
  , descStyle ::
      { marginTop :: String
      , fontSize :: String
      , lineHeight :: Number
      , color :: String
      , maxWidth :: String
      , maxHeight :: String
      , overflow :: String
      }
  , shelf :: { display :: String, flexDirection :: String, marginTop :: String }
  , shelfBox ::
      { position :: String
      , display :: String
      , alignItems :: String
      , height :: String
      , overflow :: String
      , borderBottom :: String
      }
  , track :: { display :: String, alignItems :: String, flexShrink :: Number, marginLeft :: String }
  , fadeLeft ::
      { position :: String
      , left :: String
      , top :: String
      , bottom :: String
      , width :: String
      , background :: String
      }
  , fadeRight ::
      { position :: String
      , right :: String
      , top :: String
      , bottom :: String
      , width :: String
      , background :: String
      }
  , footerRow ::
      { display :: String
      , alignItems :: String
      , marginTop :: String
      , fontFamily :: String
      , fontSize :: String
      }
  , footerMuted :: { color :: String }
  , footerLink :: { color :: String }
  }

orange :: String
orange = "#ff4800"

ink :: String
ink = "#1a1a17"

mutedColor :: String
mutedColor = "rgba(0, 0, 0, 0.5)"

descColor :: String
descColor = "rgba(0, 0, 0, 0.56)"

page :: String
page = "#f1f1ef"

pageClear :: String
pageClear = "rgba(241, 241, 239, 0)"

cardColor :: String
cardColor = "#ffffff"

borderColor :: String
borderColor = "rgba(0, 0, 0, 0.07)"

shelfLine :: String
shelfLine = "#d6d6db"

bookFill :: String
bookFill = "#e6e6ea"

bookLine :: String
bookLine = "#c8c8d0"

selFill :: String
selFill = "#dbeafe"

selLine :: String
selLine = "#3b82f6"

monoMuted :: String
monoMuted = "rgba(0, 0, 0, 0.42)"

shelfHeight :: Int
shelfHeight = 122

contentWidth :: Int
contentWidth = 1088

trackStart :: Int
trackStart = -14

fadeWidth :: Int
fadeWidth = 66

-- | The int32 bit pattern reinterpreted as JS `>>> 0` — a uint32 carried
-- | exactly in a Number.
toUint32 :: Int -> Number
toUint32 n = if n < 0 then Int.toNumber n + 4294967296.0 else Int.toNumber n

-- | JS `s >>> k` on an integer-valued uint32 Number: floor-divide by 2^k.
ushr :: Number -> Int -> Number
ushr s k = floor (s / Number.pow 2.0 (Int.toNumber k))

-- | JS `s % m` on an integer-valued uint32 Number — exact in doubles.
umod :: Number -> Int -> Int
umod s m = Int.floor (Number.remainder s (Int.toNumber m))

-- | `seedFor` from the reference: `(2166136261 ^ i + 1) >>> 0`, an `imul`
-- | round, and a xorshift fold — int32 ops on the same bit patterns, then
-- | the unsigned view. (`-2128831035` is `2166136261 | 0`.)
seedFor :: Int -> Number
seedFor i =
  let
    h0 = xor (-2128831035) (i + 1)
    h1 = runFn2 imulImpl h0 16777619
    h2 = xor h1 (zshr h1 15)
  in
    toUint32 h2

spineGeom :: Int -> { width :: Int, heightPct :: Int, gap :: Int, tilt :: Int, arc :: Number }
spineGeom i =
  let
    s = seedFor i
    roll = umod s 100
    width =
      if roll < 26 then 6 + umod s 4
      else if roll < 68 then 11 + umod (ushr s 3) 8
      else 19 + umod (ushr s 6) 9
    heightPct = 42 + umod (seedFor (i * 3 + 1)) 50
    gap = 1 + umod (seedFor (i * 7 + 5)) 4
    tilt =
      if umod s 9 == 0 then (if umod (ushr s 5) 2 /= 0 then 1 else -1) * (3 + umod (ushr s 4) 4)
      else 0
    arc = Number.max 1.5 (Number.round (Int.toNumber width * 0.18 * 10.0) / 10.0)
  in
    { width, heightPct, gap, tilt, arc }

-- | Fill the track with seeded spines until it overflows the fade, then
-- | light the one whose position maps the page's index into the shelf.
booksFor :: Int -> Int -> Array Book
booksFor index total =
  let
    fill acc x i =
      if x < contentWidth + fadeWidth && i < 200 then
        let
          g = spineGeom i
        in
          fill
            ( Array.snoc acc
                { width: g.width
                , heightPct: g.heightPct
                , gap: g.gap
                , tilt: g.tilt
                , arc: g.arc
                , lit: false
                }
            )
            (x + g.width + g.gap)
            (i + 1)
      else acc
    bare = fill [] trackStart 0
  in
    if index >= 0 && total > 0 && not (Array.null bare) then
      let
        frac = Int.toNumber index / Int.toNumber (max (total - 1) 1)
        lit = Int.round ((0.1 + frac * 0.8) * Int.toNumber (Array.length bare - 1))
      in
        fromMaybe bare (Array.modifyAt lit (_ { lit = true }) bare)
    else bare

clampDescription :: String -> String
clampDescription description =
  let
    text = normalizeDescriptionImpl description
  in
    if CodeUnits.length text > 152 then trimEndImpl (CodeUnits.take 150 text) <> "…"
    else text

bookStyle :: Book -> StyleMap
bookStyle book =
  runFn2 mkBookStyleImpl
    { display: "flex"
    , flexShrink: 0.0
    , width: show book.width <> "px"
    , height: show (Int.round (Int.toNumber book.heightPct / 100.0 * Int.toNumber shelfHeight)) <>
        "px"
    , marginRight: show book.gap <> "px"
    , backgroundColor: if book.lit then selFill else bookFill
    , border: "1px solid " <> (if book.lit then selLine else bookLine)
    , borderTopLeftRadius: toString book.arc <> "px"
    , borderTopRightRadius: toString book.arc <> "px"
    }
    ( toNullable
        ( if book.tilt /= 0 then
            Just
              { transform: "rotate(" <> show book.tilt <> "deg)"
              , transformOrigin: "bottom center"
              }
          else Nothing
        )
    )

useShelfSatori :: EffectFn1 SatoriArgs SatoriBindings
useShelfSatori = mkEffectFn1 setup

setup :: SatoriArgs -> Effect SatoriBindings
setup args = do
  books <- computed do
    index <- args.index
    total <- args.total
    pure (booksFor index total)
  clampedDescription <- computed (clampDescription <$> args.description)
  pure
    { books
    , clampedDescription
    , bookStyle
    , frame:
        { width: "1200px"
        , height: "630px"
        , display: "flex"
        , flexDirection: "column"
        , justifyContent: "space-between"
        , padding: "46px 56px"
        , backgroundColor: page
        , fontFamily: "Proxima Soft"
        }
    , card:
        { display: "flex"
        , flexDirection: "column"
        , padding: "40px 48px"
        , backgroundColor: cardColor
        , border: "1px solid " <> borderColor
        , borderRadius: "22px"
        }
    , kickerStyle:
        { fontSize: "25px"
        , color: mutedColor
        , letterSpacing: "0.01em"
        }
    , titleStyle:
        { marginTop: "14px"
        , fontSize: "52px"
        , lineHeight: 1.08
        , color: ink
        , maxWidth: "1010px"
        , maxHeight: "116px"
        , overflow: "hidden"
        }
    , descStyle:
        { marginTop: "20px"
        , fontSize: "27px"
        , lineHeight: 1.44
        , color: descColor
        , maxWidth: "1010px"
        , maxHeight: "80px"
        , overflow: "hidden"
        }
    , shelf:
        { display: "flex"
        , flexDirection: "column"
        , marginTop: "24px"
        }
    , shelfBox:
        { position: "relative"
        , display: "flex"
        , alignItems: "flex-end"
        , height: show shelfHeight <> "px"
        , overflow: "hidden"
        , borderBottom: "1px solid " <> shelfLine
        }
    , track:
        { display: "flex"
        , alignItems: "flex-end"
        , flexShrink: 0.0
        , marginLeft: show trackStart <> "px"
        }
    , fadeLeft:
        { position: "absolute"
        , left: "0"
        , top: "0"
        , bottom: "0"
        , width: show fadeWidth <> "px"
        , background: "linear-gradient(to right, " <> page <> ", " <> pageClear <> ")"
        }
    , fadeRight:
        { position: "absolute"
        , right: "0"
        , top: "0"
        , bottom: "0"
        , width: show fadeWidth <> "px"
        , background: "linear-gradient(to left, " <> page <> ", " <> pageClear <> ")"
        }
    , footerRow:
        { display: "flex"
        , alignItems: "center"
        , marginTop: "18px"
        , fontFamily: "Departure Mono"
        , fontSize: "21px"
        }
    , footerMuted: { color: monoMuted }
    , footerLink: { color: orange }
    }
