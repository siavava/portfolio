-- | ## BookshelfPanel
-- |
-- | The setup composable behind `BookshelfPanel.vue`: shapes the queried
-- | project docs into the shelf's ordering — featured first, newest year,
-- | then title — and drives the selected-card state. The SFC keeps only
-- | the content-query glue plus one call here.
module App.Components.BookshelfPanel
  ( JsValue
  , PanelArgs
  , PanelBindings
  , PanelProject
  , RawDoc
  , useBookshelfPanel
  ) where

import Prelude

import Data.Array (filter, find, index, length, sortBy)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int (floor, toNumber)
import Data.Nullable (Nullable, null, toNullable)
import Data.String.CodeUnits (take)
import Effect (Effect)
import Effect.Random (random)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , read
  , shallowRef
  , write
  )

foreign import data JsValue :: Type

foreign import jsStringImpl :: JsValue -> String
foreign import jsNumberImpl :: String -> Number
foreign import truthyImpl :: JsValue -> Boolean
foreign import localeCompareImpl :: Fn2 String String Number

type RawDoc =
  { path :: String
  , title :: String
  , summary :: String
  , tag :: String
  , date :: JsValue
  , repo :: JsValue
  , featured :: JsValue
  }

type PanelProject =
  { path :: String
  , title :: String
  , summary :: String
  , tag :: String
  , year :: Number
  , date :: String
  , repo :: JsValue
  , featured :: JsValue
  }

type PanelArgs = { docs :: Effect (Array RawDoc) }

type PanelBindings =
  { projects :: Computed (Array PanelProject)
  , selected :: Ref (Nullable PanelProject)
  , onSelect :: EffectFn1 String Unit
  }

toProject :: RawDoc -> PanelProject
toProject doc =
  { path: doc.path
  , title: doc.title
  , summary: doc.summary
  , tag: doc.tag
  , year: jsNumberImpl (take 4 (jsStringImpl doc.date))
  , date: jsStringImpl doc.date
  , repo: doc.repo
  , featured: doc.featured
  }

-- | `b.year - a.year || a.title.localeCompare(b.title)` — including the
-- | JS falsiness (`0`/`NaN`) deciding the fallthrough to the title tie
-- | break.
byYear :: PanelProject -> PanelProject -> Ordering
byYear a b =
  let
    diff = b.year - a.year
  in
    if diff < 0.0 then LT
    else if diff > 0.0 then GT
    else
      let
        order = runFn2 localeCompareImpl a.title b.title
      in
        if order < 0.0 then LT
        else if order > 0.0 then GT
        else EQ

useBookshelfPanel :: EffectFn1 PanelArgs PanelBindings
useBookshelfPanel = mkEffectFn1 setup

setup :: PanelArgs -> Effect PanelBindings
setup args = do
  projects <- computed do
    docs <- args.docs
    let items = map toProject docs
    pure
      ( sortBy byYear (filter (truthyImpl <<< _.featured) items)
          <> sortBy byYear (filter (not <<< truthyImpl <<< _.featured) items)
      )

  selected <- shallowRef (null :: Nullable PanelProject)

  let
    onSelect path = do
      pool <- read projects
      write selected (toNullable (find (\project -> project.path == path) pool))

  onMounted do
    catalog <- read projects
    let
      featured = filter (truthyImpl <<< _.featured) catalog
      pool = if length featured > 0 then featured else catalog
    roll <- random
    write selected (toNullable (index pool (floor (roll * toNumber (length pool)))))

  pure { projects, selected, onSelect: mkEffectFn1 onSelect }
