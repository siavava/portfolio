-- | Golden cases for the OG shelf card's pure core: the description clamp
-- | (recorded from the retired `\s+` / `trimEnd` FFI in bun), and the
-- | seeded spine geometry and shelf fill (recorded from the original
-- | TypeScript card). Then the pieces under them, checked against their
-- | documentation: the unsigned views of int32 bit patterns, the squash
-- | and trailing trim, the bands every seeded spine falls in, and a
-- | spine's style — its height as a share of the 122px shelf, the
-- | selection colours when lit, and a tilt only when it leans.
module Test.Components.ShelfSatori (suite) where

import Prelude

import App.Components.ShelfSatori
  ( Book
  , bookFields
  , bookTilt
  , booksFor
  , clampDescription
  , normalizeDescription
  , seedFor
  , spineGeom
  , toUint32
  , trimEnd
  , umod
  , ushr
  )
import Data.Array (all, any, filter, findIndex, length, range, replicate, take)
import Data.Foldable (fold, for_, sum)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Data.Number (round)
import Data.Ord (abs)
import Effect (Effect)
import Test.Harness (Tally, expect)

letters :: Int -> String
letters n = fold (replicate n "a")

clampCases :: Array { label :: String, input :: String, output :: String }
clampCases =
  [ { label: "empty"
    , input: ""
    , output: ""
    }
  , { label: "only whitespace"
    , input: " \t\n\r "
    , output: ""
    }
  , { label: "tabs and newlines"
    , input: "one\ttwo\n\nthree\r\nfour"
    , output: "one two three four"
    }
  , { label: "nbsp"
    , input: "a\x00A0\x00A0" <> "b"
    , output: "a b"
    }
  , { label: "line and paragraph separators"
    , input: "a\x2028" <> "b\x2029" <> "c"
    , output: "a b c"
    }
  , { label: "byte-order mark"
    , input: "\xFEFF" <> "a\xFEFF b\xFEFF"
    , output: "a b"
    }
  , { label: "vertical tab and form feed"
    , input: "a\x0B\x0C" <> "b"
    , output: "a b"
    }
  , { label: "ideographic space"
    , input: "\x3000" <> "a\x3000" <> "b\x3000"
    , output: "a b"
    }
  , { label: "zero-width space is not whitespace"
    , input: "a\x200B" <> "b"
    , output: "a\x200B" <> "b"
    }
  , { label: "next-line is not whitespace"
    , input: "a\x0085" <> "b"
    , output: "a\x0085" <> "b"
    }
  , { label: "leading and trailing"
    , input: "   padded text \n\t"
    , output: "padded text"
    }
  , { label: "exactly 152 kept whole"
    , input: letters 152
    , output: letters 152
    }
  , { label: "153 clamped to 150 plus ellipsis"
    , input: letters 153
    , output: letters 150 <> "…"
    }
  , { label: "152 once squashed"
    , input: "  " <> letters 75 <> "\n\n\t" <> letters 76 <> "  "
    , output: letters 75 <> " " <> letters 76
    }
  , { label: "cut landing on whitespace"
    , input: letters 149 <> " " <> letters 10
    , output: letters 149 <> "…"
    }
  , { label: "cut just before whitespace"
    , input: letters 150 <> " " <> letters 10
    , output: letters 150 <> "…"
    }
  , { label: "cut inside a word"
    , input: letters 100 <> " " <> letters 60
    , output: letters 100 <> " " <> letters 49 <> "…"
    }
  ]

seedCases :: Array { i :: Int, seed :: Number }
seedCases =
  [ { i: 0, seed: 67916692.0 }
  , { i: 1, seed: 118255197.0 }
  , { i: 2, seed: 101470890.0 }
  , { i: 3, seed: 17585355.0 }
  , { i: 7, seed: 218919855.0 }
  , { i: 42, seed: 772587955.0 }
  , { i: 199, seed: 1292607841.0 }
  , { i: 1000, seed: 1812735837.0 }
  , { i: 123456, seed: 3312334355.0 }
  ]

type Geom = { width :: Int, heightPct :: Int, gap :: Int, tilt :: Int, arc :: Number }

spineCases :: Array { i :: Int, geom :: Geom }
spineCases =
  [ { i: 0, geom: { width: 27, heightPct: 89, gap: 2, tilt: 0, arc: 4.9 } }
  , { i: 3, geom: { width: 12, heightPct: 44, gap: 4, tilt: 0, arc: 2.2 } }
  , { i: 5, geom: { width: 7, heightPct: 60, gap: 2, tilt: 0, arc: 1.5 } }
  , { i: 9, geom: { width: 11, heightPct: 74, gap: 4, tilt: 0, arc: 2.0 } }
  , { i: 16, geom: { width: 25, heightPct: 90, gap: 2, tilt: 0, arc: 4.5 } }
  , { i: 18, geom: { width: 18, heightPct: 86, gap: 1, tilt: 6, arc: 3.2 } }
  , { i: 34, geom: { width: 12, heightPct: 53, gap: 2, tilt: -3, arc: 2.2 } }
  , { i: 47, geom: { width: 17, heightPct: 73, gap: 3, tilt: 0, arc: 3.1 } }
  , { i: 53, geom: { width: 6, heightPct: 89, gap: 2, tilt: 0, arc: 1.5 } }
  , { i: 59, geom: { width: 26, heightPct: 67, gap: 3, tilt: 0, arc: 4.7 } }
  ]

litCases :: Array { index :: Int, total :: Int, lit :: Maybe Int }
litCases =
  [ { index: -1, total: 0, lit: Nothing }
  , { index: -1, total: 5, lit: Nothing }
  , { index: 0, total: 0, lit: Nothing }
  , { index: 3, total: 0, lit: Nothing }
  , { index: 0, total: 1, lit: Just 6 }
  , { index: 0, total: 5, lit: Just 6 }
  , { index: 2, total: 5, lit: Just 32 }
  , { index: 4, total: 5, lit: Just 57 }
  , { index: 1, total: 3, lit: Just 32 }
  , { index: 1, total: 2, lit: Just 57 }
  , { index: 5, total: 6, lit: Just 57 }
  , { index: 7, total: 12, lit: Just 38 }
  , { index: 11, total: 12, lit: Just 57 }
  , { index: 9, total: 5, lit: Nothing }
  ]

suite :: Tally -> Effect Unit
suite t = do
  for_ clampCases \c ->
    expect t ("clampDescription " <> c.label) c.output (clampDescription c.input)

  for_ seedCases \c ->
    expect t ("seedFor " <> show c.i) c.seed (seedFor c.i)

  for_ spineCases \c ->
    expect t ("spineGeom " <> show c.i) c.geom (spineGeom c.i)

  let bare = booksFor (-1) 0
  expect t "booksFor fills 64 spines" 64 (length bare)
  expect t "booksFor opens with the recorded run"
    [ { width: 27, heightPct: 89, gap: 2, tilt: 0, arc: 4.9, lit: false }
    , { width: 20, heightPct: 72, gap: 1, tilt: 0, arc: 3.6, lit: false }
    , { width: 25, heightPct: 47, gap: 4, tilt: 0, arc: 4.5, lit: false }
    , { width: 12, heightPct: 44, gap: 4, tilt: 0, arc: 2.2, lit: false }
    ]
    (take 4 bare)
  expect t "booksFor stops at the first spine past the fade (x from -14)"
    { before: 1158, after: 1184 }
    { before: sum (map (\b -> b.width + b.gap) (take 63 bare))
    , after: sum (map (\b -> b.width + b.gap) bare)
    }

  for_ litCases \c -> do
    let
      books = booksFor c.index c.total
      label = "booksFor " <> show c.index <> "/" <> show c.total
    expect t (label <> " lit spine") c.lit (findIndex _.lit books)
    expect t (label <> " lights at most one")
      (if c.lit == Nothing then 0 else 1)
      (length (filter _.lit books))

  expect t "a non-negative int32 is its own unsigned view" [ 0.0, 1.0, 2147483647.0 ]
    (map toUint32 [ 0, 1, top ])
  expect t "-1 is the largest uint32" 4294967295.0 (toUint32 (-1))
  expect t "the lowest int32 is 2^31 unsigned" 2147483648.0 (toUint32 bottom)
  expect t "an unsigned shift by 0 keeps the value" 5.0 (ushr 5.0 0)
  expect t "an unsigned shift floor-divides by a power of two" [ 1.0, 0.0, 2147483647.0 ]
    [ ushr 8.0 3, ushr 7.0 3, ushr 4294967295.0 1 ]
  expect t "an unsigned remainder is exact above 2^31" 95 (umod 4294967295.0 100)
  expect t "a seed's roll is its last two digits" 92 (umod 67916692.0 100)

  expect t "the squash collapses every run and trims both ends" "one two three"
    (normalizeDescription "  one \n\t two   three \r\n")
  expect t "trimEnd drops only the trailing run" "  a b" (trimEnd "  a b \n\t")
  expect t "trimEnd leaves text without a trailing run alone" "a b" (trimEnd "a b")

  let
    spines = map spineGeom (range 0 199)
    inBand w = (w >= 6 && w <= 9) || (w >= 11 && w <= 18) || (w >= 19 && w <= 27)
    rounded w = max 1.5 (round (toNumber w * 1.8) / 10.0)
  expect t "every spine's width falls in the narrow, middle or wide band" true
    (all (inBand <<< _.width) spines)
  expect t "every spine stands between 42% and 91% of the shelf" true
    (all (\g -> g.heightPct >= 42 && g.heightPct <= 91) spines)
  expect t "every gap is one to four pixels" true (all (\g -> g.gap >= 1 && g.gap <= 4) spines)
  expect t "a leaning spine leans three to six degrees either way" true
    (all (\g -> g.tilt == 0 || (abs g.tilt >= 3 && abs g.tilt <= 6)) spines)
  expect t "most spines stand upright but some lean" true
    (any ((_ /= 0) <<< _.tilt) spines && length (filter ((_ == 0) <<< _.tilt) spines) > 100)
  expect t "a spine's arc is 18% of its width to a tenth, never under 1.5px" true
    (all (\g -> g.arc == rounded g.width) spines)

  let
    upright :: Book
    upright = { width: 12, heightPct: 50, gap: 3, tilt: 0, arc: 2.2, lit: false }
  expect t "a spine's style carries its size, gap and arc"
    { display: "flex"
    , flexShrink: 0.0
    , width: "12px"
    , height: "61px"
    , marginRight: "3px"
    , backgroundColor: "#e6e6ea"
    , border: "1px solid #c8c8d0"
    , borderTopLeftRadius: "2.2px"
    , borderTopRightRadius: "2.2px"
    }
    (bookFields upright)
  expect t "the lit spine wears the selection colours"
    { fill: "#dbeafe", border: "1px solid #3b82f6" }
    ( let
        fields = bookFields upright { lit = true }
      in
        { fill: fields.backgroundColor, border: fields.border }
    )
  expect t "a spine's height rounds its share of the shelf to whole pixels"
    [ "51px", "109px", "111px" ]
    (map (\pct -> (bookFields upright { heightPct = pct }).height) [ 42, 89, 91 ])
  expect t "a whole arc is written without decimals" "2px"
    (bookFields upright { arc = 2.0 }).borderTopLeftRadius
  expect t "an upright spine has no tilt" Nothing (toMaybe (bookTilt upright))
  expect t "a spine leaning left rotates about its foot"
    (Just { transform: "rotate(-3deg)", transformOrigin: "bottom center" })
    (toMaybe (bookTilt upright { tilt = -3 }))
  expect t "a spine leaning right rotates about its foot"
    (Just { transform: "rotate(6deg)", transformOrigin: "bottom center" })
    (toMaybe (bookTilt upright { tilt = 6 }))
