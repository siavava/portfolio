-- | Golden cases for the seeded bookshelf spine geometry, extracted from
-- | recordings of the original TypeScript implementation.
module Test.Utils.Spines (suite) where

import Prelude

import App.Utils.Spines (SpineStyleJs, hashLabel, spineStyle)
import Data.Foldable (for_)
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

suite :: Tally -> Effect Unit
suite t = for_ cases \c -> do
  expect t ("hashLabel " <> show c.input) c.hash (hashLabel c.input)
  expect t ("spineStyle " <> show c.input) c.style (spineStyle c.input)
