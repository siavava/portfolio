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
  , setup
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
  , ref
  , shallowRef
  , watchGetter
  , write
  )

-- | A raw `KeyboardEvent`. @ts KeyboardEvent
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

-- | The doc's route path.
foreign import docPathImpl :: ProjectDoc -> String

-- | The doc's category tag.
foreign import docTagImpl :: ProjectDoc -> String

-- | The doc's title.
foreign import docTitleImpl :: ProjectDoc -> String

-- | The doc's date, stringified.
foreign import docDateImpl :: ProjectDoc -> String

-- | The doc's summary, empty when absent.
foreign import docSummaryImpl :: ProjectDoc -> String

-- | The doc's featured flag, by JS truthiness.
foreign import docFeaturedImpl :: ProjectDoc -> Boolean

-- | The flattened text of the doc body's first minimark paragraph.
foreign import openingTextImpl :: ProjectDoc -> String

-- | `a.localeCompare(b)`.
foreign import localeCompareImpl :: Fn2 String String Number

-- | The route's catch-all slug segments, empty falsy parts dropped.
foreign import slugPartsImpl :: EffectFn1 RouteHandle (Array String)

-- | The route's current path.
foreign import routePathNowImpl :: EffectFn1 RouteHandle String

-- | `router.replace(path)`, promise discarded.
foreign import routerReplaceImpl :: EffectFn2 RouterHandle String Unit

-- | Calls the rail's exposed `center(key, behavior)` when it's mounted.
foreign import railCenterImpl :: EffectFn3 (Ref (Nullable RailHandle)) String String Unit

-- | Smooth-scrolls the window to the top, only on ≤1440px viewports
-- | (where the rail is a drawer). SSR-safe no-op.
foreign import scrollTopIfNarrowImpl :: Effect Unit

-- | Passive window scroll listener via VueUse `useEventListener` —
-- | cleans up with the component scope, hence no returned remover.
foreign import watchWindowScrollImpl :: EffectFn1 (Effect Unit) Unit

-- | `window.scrollY`, 0 during SSR.
foreign import windowScrollYImpl :: Effect Number

-- | Window keydown listener via VueUse `useEventListener` — cleans up
-- | with the component scope.
foreign import onKeydownImpl :: EffectFn1 (EffectFn1 KeyEvt Unit) Unit

-- | `event.key`.
foreign import keyOfImpl :: KeyEvt -> String

-- | Whether meta, ctrl, or alt is held.
foreign import hasModifierImpl :: KeyEvt -> Boolean

-- | Whether the event targets an input, textarea, or contenteditable.
foreign import isEditableTargetImpl :: KeyEvt -> Boolean

-- | `event.preventDefault()`.
foreign import preventDefaultImpl :: EffectFn1 KeyEvt Unit

-- | One shelf of the bookcase rail.
type DocGroup =
  { -- | Shelf key: the tag, or "featured".
    key :: String
  -- | Title-cased shelf label.
  , label :: String
  -- | The shelf's docs, in query order.
  , items :: Array ProjectDoc
  }

type ReaderArgs =
  { -- | Reads the queried project docs.
    docs :: Effect (Array ProjectDoc)
  -- | The current route — selection follows its catch-all slug.
  , route :: RouteHandle
  -- | The router; selection replaces the path.
  , router :: RouterHandle
  -- | Template ref to the BookcaseRail component (exposes `center`).
  , rail :: Ref (Nullable RailHandle)
  -- | The figure-spotlight state ref; opening it clears the peeks.
  , spotlight :: Ref (Nullable SpotVal)
  -- | Dismisses any open figure/reference peeks.
  , clearPeeks :: Effect Unit
  -- | Closes the figure spotlight.
  , closeSpotlight :: Effect Unit
  }

type ReaderBindings =
  { -- | The queried docs, as a computed.
    docs :: Computed (Array ProjectDoc)
  -- | Rail shelves: a Featured shelf first when any doc is featured,
  -- | then tag shelves, newest first.
  , groups :: Computed (Array DocGroup)
  -- | The doc being read; falls back to featured, then the first doc.
  , selected :: Ref (Nullable ProjectDoc)
  -- | Whether to render the summary dek — hidden when the article's
  -- | opening paragraph already restates it.
  , showDek :: Computed Boolean
  -- | Mobile drawer open state.
  , drawer :: Ref Boolean
  -- | Reading order across the non-featured shelves — what arrow keys
  -- | step through.
  , ordered :: Computed (Array ProjectDoc)
  -- | Index of the selected doc in `ordered`, -1 when absent.
  , selectedIndex :: Computed Int
  -- | True once the window has scrolled past 4px — topbar styling.
  , stuck :: Ref Boolean
  -- | Absolute URL of the selected project, for the topbar share.
  , shareUrl :: Computed String
  -- | `useSeoMeta` title for the selected project (or the index).
  , seoTitle :: Computed String
  -- | `useSeoMeta` description — the summary, whitespace-collapsed.
  , seoDescription :: Computed String
  -- | Canonical URL for the current route.
  , canonical :: Computed String
  -- | OG-image kicker line: "Tag · Year" (or the portfolio default).
  , ogKicker :: Computed String
  -- | OG-image title.
  , ogTitle :: Computed String
  -- | OG-image description.
  , ogDescription :: Computed String
  -- | Shelf index fed to the OG image; -1 on the bare `/projects` route.
  , ogIndex :: Computed Int
  -- | Selects a project by path (closes the drawer, replaces the
  -- | route); the optional group key steers the rail centering.
  , select :: EffectFn2 String (Nullable String) Unit
  -- | Steps the selection by ±1 through `ordered`, wrapping.
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

-- | Wires the projects reader: shelf grouping, route-driven selection
-- | with rail centering, dek suppression, arrow-key stepping and the
-- | drawer Escape, the scroll-stuck flag, and the SEO/OG text feeds.
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
  runEffectFn1 watchWindowScrollImpl do
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

  activeDoc <- computed do
    active <- read onProject
    mSelected <- toMaybe <$> read selected
    pure (if active then mSelected else Nothing)

  seoTitle <- computed do
    mDoc <- read activeDoc
    pure
      ( maybe "Projects · Amittai Siavava"
          (\doc -> docTitleImpl doc <> " · Projects · Amittai Siavava")
          mDoc
      )

  seoDescription <- computed do
    mDoc <- read activeDoc
    pure (collapseWs (maybe pageDescription docSummaryImpl mDoc))

  canonical <- computed do
    mPath <- toMaybe <$> read routePath
    pure (siteOrigin <> fromMaybe "/projects" mPath)

  shareUrl <- computed do
    mSelected <- toMaybe <$> read selected
    pure (siteOrigin <> maybe "/projects" docPathImpl mSelected)

  ogKicker <- computed do
    mDoc <- read activeDoc
    pure
      ( maybe "Portfolio · Dartmouth"
          (\doc -> titleCase (docTagImpl doc) <> " · " <> CU.take 4 (docDateImpl doc))
          mDoc
      )

  ogTitle <- computed do
    mDoc <- read activeDoc
    pure (maybe "Projects" docTitleImpl mDoc)

  ogDescription <- computed do
    mDoc <- read activeDoc
    pure (maybe pageDescription docSummaryImpl mDoc)

  ogIndex <- computed do
    mDoc <- read activeDoc
    if isJust mDoc then read selectedIndex else pure (-1)

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
