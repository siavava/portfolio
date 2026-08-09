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
  , setup
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

-- | An arbitrary JS value — the optional content-query fields, kept
-- | opaque and read through JS coercion semantics.
foreign import data JsValue :: Type

-- | JS `String(value)` coercion.
foreign import jsStringImpl :: JsValue -> String

-- | JS `Number(value)` coercion — `NaN` when unparsable.
foreign import jsNumberImpl :: String -> Number

-- | JS truthiness of the value.
foreign import truthyImpl :: JsValue -> Boolean

-- | `a.localeCompare(b)`.
foreign import localeCompareImpl :: Fn2 String String Number

-- | One queried project doc, as the SFC selects it.
type RawDoc =
  { -- | Route path of the project page.
    path :: String
  -- | Project title.
  , title :: String
  -- | Short summary blurb (empty when the doc has none).
  , summary :: String
  -- | Category tag (empty when the doc has none).
  , tag :: String
  -- | Doc date as queried — any JS value, stringified downstream.
  , date :: JsValue
  -- | Optional repo URL, possibly undefined.
  , repo :: JsValue
  -- | Optional featured flag, judged by JS truthiness.
  , featured :: JsValue
  }

-- | A shelf entry: the doc plus its derived year and date string.
type PanelProject =
  { -- | Route path of the project page.
    path :: String
  -- | Project title.
  , title :: String
  -- | Short summary blurb.
  , summary :: String
  -- | Category tag.
  , tag :: String
  -- | Year parsed from the date's first four characters (`NaN` capable).
  , year :: Number
  -- | The doc date stringified.
  , date :: String
  -- | Optional repo URL, passed through untouched.
  , repo :: JsValue
  -- | Optional featured flag, judged by JS truthiness.
  , featured :: JsValue
  }

type PanelArgs =
  { -- | Reads the queried project docs (empty while loading).
    docs :: Effect (Array RawDoc)
  }

type PanelBindings =
  { -- | Shelf ordering: featured first, then newest year, then title.
    projects :: Computed (Array PanelProject)
  -- | The project shown on the card; seeded randomly on mount.
  , selected :: Ref (Nullable PanelProject)
  -- | Shelf select handler: picks the project with the given path.
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

-- | Shapes the queried project docs into the shelf ordering — featured
-- | first, newest year, then title — and drives the selected card,
-- | seeding it with a random (preferably featured) project on mount.
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
