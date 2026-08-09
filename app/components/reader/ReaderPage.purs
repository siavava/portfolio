-- | ## ReaderPage
-- |
-- | The setup composable behind `pages/projects/[...slug].vue`: shelf
-- | grouping, route-driven selection, dek suppression, keyboard and
-- | scroll listeners, and the SEO/OG text feeds. The SFC keeps only the
-- | content query, the compiler macros, template refs, glue composables
-- | the template binds, and one call here. The module lives under
-- | `app/components/` because a generated FFI stub in `app/pages/`
-- | would be scanned as a route.
module App.Components.ReaderPage
  ( DocGroup
  , KeyEvt
  , ProjectDoc
  , RailHandle
  , ReaderArgs
  , ReaderBindings
  , RouteHandle
  , RouterHandle
  , SpotVal
  , useReaderPage
  ) where

import Prelude

import App.Utils.Format (titleCase)
import Data.Array
  ( concatMap
  , cons
  , filter
  , find
  , findIndex
  , head
  , index
  , length
  , modifyAt
  , null
  , snoc
  , sortBy
  ) as Array
import Data.Foldable (foldl, for_)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..), fromMaybe, isJust, maybe)
import Data.Nullable (Nullable, notNull, null, toMaybe, toNullable)
import Data.String (Pattern(..), joinWith, stripPrefix, toLower, trim)
import Data.String.CodeUnits (take) as CU
import Data.String.Regex (Regex)
import Data.String.Regex (replace) as Regex
import Data.String.Regex.Flags (global, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , read
  , read
  , ref
  , shallowRef
  , watchGetter
  , write
  )

-- | A raw `KeyboardEvent`.
foreign import data KeyEvt :: Type

-- | One projects-collection document — opaque; field access happens in
-- | the FFI.
foreign import data ProjectDoc :: Type

-- | The BookcaseRail's exposed surface (`center`).
foreign import data RailHandle :: Type

-- | The current `vue-router` route.
foreign import data RouteHandle :: Type

-- | The `vue-router` router.
foreign import data RouterHandle :: Type

-- | Whatever the figure spotlight holds when open.
foreign import data SpotVal :: Type

foreign import docPathImpl :: ProjectDoc -> String
foreign import docTagImpl :: ProjectDoc -> String
foreign import docTitleImpl :: ProjectDoc -> String
foreign import docDateImpl :: ProjectDoc -> String
foreign import docSummaryImpl :: ProjectDoc -> String
foreign import docFeaturedImpl :: ProjectDoc -> Boolean
foreign import openingTextImpl :: ProjectDoc -> String
foreign import localeCompareImpl :: Fn2 String String Number
foreign import slugPartsImpl :: EffectFn1 RouteHandle (Array String)
foreign import routePathNowImpl :: EffectFn1 RouteHandle String
foreign import routerReplaceImpl :: EffectFn2 RouterHandle String Unit
foreign import railCenterImpl :: EffectFn3 (Ref (Nullable RailHandle)) String String Unit
foreign import scrollTopIfNarrowImpl :: Effect Unit
foreign import onWindowScrollImpl :: EffectFn1 (Effect Unit) Unit
foreign import windowScrollYImpl :: Effect Number
foreign import onKeydownImpl :: EffectFn1 (EffectFn1 KeyEvt Unit) Unit
foreign import keyOfImpl :: KeyEvt -> String
foreign import hasModifierImpl :: KeyEvt -> Boolean
foreign import isEditableTargetImpl :: KeyEvt -> Boolean
foreign import preventDefaultImpl :: EffectFn1 KeyEvt Unit

-- | One shelf of the bookcase rail.
type DocGroup = { key :: String, label :: String, items :: Array ProjectDoc }

type ReaderArgs =
  { docs :: Effect (Array ProjectDoc)
  , route :: RouteHandle
  , router :: RouterHandle
  , rail :: Ref (Nullable RailHandle)
  , spotlight :: Ref (Nullable SpotVal)
  , clearPeeks :: Effect Unit
  , closeSpotlight :: Effect Unit
  }

type ReaderBindings =
  { docs :: Computed (Array ProjectDoc)
  , groups :: Computed (Array DocGroup)
  , selected :: Ref (Nullable ProjectDoc)
  , showDek :: Computed Boolean
  , drawer :: Ref Boolean
  , ordered :: Computed (Array ProjectDoc)
  , selectedIndex :: Computed Int
  , stuck :: Ref Boolean
  , shareUrl :: Computed String
  , seoTitle :: Computed String
  , seoDescription :: Computed String
  , canonical :: Computed String
  , ogKicker :: Computed String
  , ogTitle :: Computed String
  , ogDescription :: Computed String
  , ogIndex :: Computed Int
  , select :: EffectFn2 String (Nullable String) Unit
  , step :: EffectFn1 Int Unit
  }

pageDescription :: String
pageDescription =
  "Four years of projects, preserved — compilers, chess bots, search engines, simulations, and everything else built at Dartmouth."

siteOrigin :: String
siteOrigin = "https://amittai.studio"

whitespaceRun :: Regex
whitespaceRun = unsafeRegex "\\s+" global

trailingDots :: Regex
trailingDots = unsafeRegex "[.…]+$" noFlags

-- | `replace(/\s+/g, " ").trim()`.
collapseWs :: String -> String
collapseWs = trim <<< Regex.replace whitespaceRun " "

-- | The featured document, else the first, else nothing.
fallbackDoc :: Array ProjectDoc -> Maybe ProjectDoc
fallbackDoc docs = case Array.find docFeaturedImpl docs of
  Just doc -> Just doc
  Nothing -> Array.head docs

-- | Insertion-ordered by-tag grouping.
groupByTag :: Array ProjectDoc -> Array { key :: String, items :: Array ProjectDoc }
groupByTag = foldl step []
  where
  step acc doc =
    let
      tag = docTagImpl doc
    in
      case Array.findIndex (\entry -> entry.key == tag) acc of
        Just i -> fromMaybe acc
          (Array.modifyAt i (\entry -> entry { items = Array.snoc entry.items doc }) acc)
        Nothing -> Array.snoc acc { key: tag, items: [ doc ] }

-- | Newest shelf first, by the first item's date (`localeCompare` desc).
shelfOrder
  :: { key :: String, items :: Array ProjectDoc }
  -> { key :: String, items :: Array ProjectDoc }
  -> Ordering
shelfOrder a b =
  let
    dateOf entry = maybe "" docDateImpl (Array.head entry.items)
    diff = runFn2 localeCompareImpl (dateOf b) (dateOf a)
  in
    if diff < 0.0 then LT else if diff > 0.0 then GT else EQ

useReaderPage :: EffectFn1 ReaderArgs ReaderBindings
useReaderPage = mkEffectFn1 setup

setup :: ReaderArgs -> Effect ReaderBindings
setup args = do
  docs <- computed args.docs

  groups <- computed do
    ds <- read docs
    let
      shelves = Array.sortBy shelfOrder (groupByTag ds)
        <#> \entry -> { key: entry.key, label: titleCase entry.key, items: entry.items }
      featured = Array.filter docFeaturedImpl ds
    pure
      if Array.null featured then shelves
      else Array.cons { key: "featured", label: "Featured", items: featured } shelves

  routePath <- computed do
    parts <- runEffectFn1 slugPartsImpl args.route
    pure
      if Array.null parts then null
      else notNull ("/projects/" <> joinWith "/" parts)

  initialDocs <- args.docs
  initialPath <- toMaybe <$> read routePath
  selected <- shallowRef $ toNullable
    case initialPath >>= \p -> Array.find (\doc -> docPathImpl doc == p) initialDocs of
      Just doc -> Just doc
      Nothing -> fallbackDoc initialDocs

  showDek <- computed do
    mSelected <- toMaybe <$> read selected
    pure case mSelected of
      Nothing -> false
      Just doc ->
        let
          summary = docSummaryImpl doc
        in
          if summary == "" then false
          else
            let
              opening = toLower (collapseWs (openingTextImpl doc))
              dek = Regex.replace trailingDots "" (toLower (collapseWs summary))
            in
              not (isJust (stripPrefix (Pattern (CU.take 40 dek)) opening))

  drawer <- ref false
  centerGroup <- Ref.new (Nothing :: Maybe String)

  let
    select path mGroupKey = do
      write drawer false
      current <- runEffectFn1 routePathNowImpl args.route
      when (path /= current) do
        Ref.write mGroupKey centerGroup
        runEffectFn2 routerReplaceImpl args.router path

  _ <- watchGetter (read routePath) \path _ -> do
    ds <- read docs
    let
      found = toMaybe path >>= \p -> Array.find (\doc -> docPathImpl doc == p) ds
      mDoc = case found of
        Just doc -> Just doc
        Nothing -> fallbackDoc ds
    for_ mDoc \doc -> do
      mSelected <- toMaybe <$> read selected
      when (Just (docPathImpl doc) /= map docPathImpl mSelected) do
        write selected (notNull doc)
        mGroupKey <- Ref.read centerGroup
        runEffectFn3 railCenterImpl args.rail (fromMaybe (docTagImpl doc) mGroupKey) "smooth"
        scrollTopIfNarrowImpl
    Ref.write Nothing centerGroup

  onMounted do
    mSelected <- toMaybe <$> read selected
    for_ mSelected \doc ->
      runEffectFn3 railCenterImpl args.rail
        (if docFeaturedImpl doc then "featured" else docTagImpl doc)
        "instant"

  ordered <- computed do
    gs <- read groups
    pure (Array.concatMap _.items (Array.filter (\group -> group.key /= "featured") gs))

  selectedIndex <- computed do
    list <- read ordered
    mSelected <- toMaybe <$> read selected
    pure case mSelected of
      Nothing -> -1
      Just doc -> fromMaybe (-1) (Array.findIndex (\d -> docPathImpl d == docPathImpl doc) list)

  let
    step direction = do
      list <- read ordered
      unless (Array.null list) do
        idx <- read selectedIndex
        let len = Array.length list
        for_ (Array.index list ((idx + direction + len) `mod` len)) \next ->
          select (docPathImpl next) (Just (docTagImpl next))

  stuck <- ref false
  runEffectFn1 onWindowScrollImpl do
    y <- windowScrollYImpl
    write stuck (y > 4.0)

  runEffectFn1 onKeydownImpl $ mkEffectFn1 \event -> do
    open <- read drawer
    let key = keyOfImpl event
    if key == "Escape" && open then write drawer false
    else if key /= "ArrowLeft" && key /= "ArrowRight" then pure unit
    else if hasModifierImpl event then pure unit
    else if isEditableTargetImpl event then pure unit
    else do
      runEffectFn1 preventDefaultImpl event
      step (if key == "ArrowRight" then 1 else -1)

  _ <- watchGetter (read args.spotlight) \value _ ->
    when (isJust (toMaybe value)) args.clearPeeks

  _ <- watchGetter (read routePath) \_ _ -> do
    args.clearPeeks
    args.closeSpotlight

  onProject <- computed do
    mPath <- toMaybe <$> read routePath
    mSelected <- toMaybe <$> read selected
    pure (isJust mPath && isJust mSelected)

  seoTitle <- computed do
    active <- read onProject
    mSelected <- toMaybe <$> read selected
    pure case mSelected of
      Just doc | active -> docTitleImpl doc <> " · Projects · Amittai Siavava"
      _ -> "Projects · Amittai Siavava"

  seoDescription <- computed do
    active <- read onProject
    mSelected <- toMaybe <$> read selected
    pure $ collapseWs case mSelected of
      Just doc | active -> docSummaryImpl doc
      _ -> pageDescription

  canonical <- computed do
    mPath <- toMaybe <$> read routePath
    pure (siteOrigin <> fromMaybe "/projects" mPath)

  shareUrl <- computed do
    mSelected <- toMaybe <$> read selected
    pure (siteOrigin <> maybe "/projects" docPathImpl mSelected)

  ogKicker <- computed do
    active <- read onProject
    mSelected <- toMaybe <$> read selected
    pure case mSelected of
      Just doc | active -> titleCase (docTagImpl doc) <> " · " <> CU.take 4 (docDateImpl doc)
      _ -> "Portfolio · Dartmouth"

  ogTitle <- computed do
    active <- read onProject
    mSelected <- toMaybe <$> read selected
    pure case mSelected of
      Just doc | active -> docTitleImpl doc
      _ -> "Projects"

  ogDescription <- computed do
    active <- read onProject
    mSelected <- toMaybe <$> read selected
    pure case mSelected of
      Just doc | active -> docSummaryImpl doc
      _ -> pageDescription

  ogIndex <- computed do
    active <- read onProject
    if not active then pure (-1)
    else do
      list <- read ordered
      mSelected <- toMaybe <$> read selected
      pure case mSelected of
        Just doc -> fromMaybe (-1) (Array.findIndex (\d -> docPathImpl d == docPathImpl doc) list)
        Nothing -> -1

  pure
    { docs
    , groups
    , selected
    , showDek
    , drawer
    , ordered
    , selectedIndex
    , stuck
    , shareUrl
    , seoTitle
    , seoDescription
    , canonical
    , ogKicker
    , ogTitle
    , ogDescription
    , ogIndex
    , select: mkEffectFn2 \path groupKey -> select path (toMaybe groupKey)
    , step: mkEffectFn1 step
    }
