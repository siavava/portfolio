-- | Golden cases for the seeded bookshelf spine geometry, extracted from
-- | recordings of the original TypeScript implementation, plus the shape
-- | every spine keeps whatever its title: the hash is the classic
-- | `hash * 31 + unit` over each code point's first UTF-16 unit and is never
-- | negative, and a spine is 7–21px wide, 50–85% tall, nudged 0 or 1px, and
-- | either straight or leaning 4–7 degrees one way or the other.
module Test.Utils.Spines (suite) where

import Prelude

import App.Utils.Spines (SpineStyleJs, hashLabel, spineStyle)
import Data.Array (all, range)
import Data.Foldable (for_)
import Data.Int (fromString)
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), stripPrefix, stripSuffix)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Case = { input :: String, hash :: Int, style :: SpineStyleJs }

cases :: Array Case
cases =
  [ { input: ""
    , hash: 0
    , style:
        { width: "7px"
        , height: "50%"
        , marginLeft: "0px"
        , borderRadius: "50% / 1.5px"
        , transform: "rotate(-4deg)"
        }
    }
  , { input: "hello, world"
    , hash: 640608884
    , style:
        { width: "9px"
        , height: "79%"
        , marginLeft: "1px"
        , borderRadius: "50% / 1.6px"
        , transform: ""
        }
    }
  , { input: "Attention Is All You Need"
    , hash: 1543383018
    , style:
        { width: "17px"
        , height: "72%"
        , marginLeft: "1px"
        , borderRadius: "50% / 3.1px"
        , transform: ""
        }
    }
  , { input: "astra"
    , hash: 93122609
    , style:
        { width: "11px"
        , height: "78%"
        , marginLeft: "0px"
        , borderRadius: "50% / 2px"
        , transform: ""
        }
    }
  , { input: "A Very Long Book Title That Overflows The Shelf Entirely"
    , hash: 1230275877
    , style:
        { width: "21px"
        , height: "67%"
        , marginLeft: "0px"
        , borderRadius: "50% / 3.8px"
        , transform: ""
        }
    }
  , { input: "ゼロから作る"
    , hash: 241910274
    , style:
        { width: "14px"
        , height: "66%"
        , marginLeft: "0px"
        , borderRadius: "50% / 2.5px"
        , transform: ""
        }
    }
  , { input: "🎉🎉🎉"
    , hash: 54968508
    , style:
        { width: "13px"
        , height: "77%"
        , marginLeft: "0px"
        , borderRadius: "50% / 2.3px"
        , transform: ""
        }
    }
  , { input: "naïve café — résumé"
    , hash: 626638389
    , style:
        { width: "13px"
        , height: "67%"
        , marginLeft: "0px"
        , borderRadius: "50% / 2.3px"
        , transform: "rotate(7deg)"
        }
    }
  ]

titles :: Array String
titles =
  map _.input cases
    <> map (\i -> "Volume " <> show i) (range 1 60)
    <> map (\i -> "An Exceedingly Long Title For A Book, Part " <> show i) (range 1 20)

intWithin :: String -> String -> String -> Maybe Int
intWithin prefix suffix text = stripPrefix (Pattern prefix) text
  >>= stripSuffix (Pattern suffix)
  >>= fromString

inRange :: Int -> Int -> Maybe Int -> Boolean
inRange lo hi = case _ of
  Just n -> n >= lo && n <= hi
  Nothing -> false

leansWell :: String -> Boolean
leansWell = case _ of
  "" -> true
  transform -> case intWithin "rotate(" "deg)" transform of
    Just n -> (n >= 4 && n <= 7) || (n >= -7 && n <= -4)
    Nothing -> false

suite :: Tally -> Effect Unit
suite t = do
  for_ cases \c -> do
    expect t ("hashLabel " <> show c.input) c.hash (hashLabel c.input)
    expect t ("spineStyle " <> show c.input) c.style (spineStyle c.input)

  expect t "hashLabel of one letter is its code unit" 97 (hashLabel "a")
  expect t "hashLabel folds hash * 31 + unit" (97 * 31 + 98) (hashLabel "ab")
  expect t "hashLabel folds left to right" ((97 * 31 + 98) * 31 + 99) (hashLabel "abc")
  expect t "hashLabel reads only an astral character's first unit (0xD83C)" 55356
    (hashLabel "🎉")
  expect t "hashLabel tells anagrams apart" false (hashLabel "stone" == hashLabel "notes")
  expect t "hashLabel is never negative, even after wrapping" true
    (all (\title -> hashLabel title >= 0) titles)

  let styles = map spineStyle titles
  expect t "every spine is 7 to 21px wide" true
    (all (inRange 7 21 <<< intWithin "" "px" <<< _.width) styles)
  expect t "every spine is 50 to 85% of the shelf tall" true
    (all (inRange 50 85 <<< intWithin "" "%" <<< _.height) styles)
  expect t "every spine is nudged 0 or 1px" true
    (all (\style -> style.marginLeft == "0px" || style.marginLeft == "1px") styles)
  expect t "every spine's edge arc is an elliptical radius in px" true
    ( all
        ( \style -> case stripPrefix (Pattern "50% / ") style.borderRadius of
            Just arc -> stripSuffix (Pattern "px") arc /= Nothing
            Nothing -> false
        )
        styles
    )
  expect t "every spine stands straight or leans 4 to 7 degrees either way" true
    (all (leansWell <<< _.transform) styles)
