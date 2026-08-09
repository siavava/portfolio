-- | ## ReaderTopbar
-- |
-- | The setup composable behind `ReaderTopbar.vue`: the share action —
-- | native share with clipboard fallback — and the pixel-icon path data.
-- | The SFC keeps only the macros and the clipboard/share glue plus one
-- | call here.
module App.Components.ReaderTopbar
  ( CopyFn
  , ShareFn
  , TopbarArgs
  , TopbarBindings
  , setup
  ) where

import Prelude

import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn4, runEffectFn2, runEffectFn4)
import Vue (Ref, read)

-- | VueUse `useShare`'s `share` function.
foreign import data ShareFn :: Type

-- | VueUse `useClipboard`'s `copy` function.
foreign import data CopyFn :: Type

-- | Tries the native share sheet; on failure other than the user
-- | cancelling (AbortError), copies the URL instead.
foreign import shareWithFallbackImpl :: EffectFn4 ShareFn CopyFn (Nullable String) String Unit

-- | Copies the URL, promise discarded.
foreign import copyRunImpl :: EffectFn2 CopyFn String Unit

type TopbarArgs =
  { -- | VueUse `useShare`'s `isSupported` — native share availability.
    canShare :: Ref Boolean
  -- | The native share function.
  , share :: ShareFn
  -- | The clipboard copy function (drives the `copied` flash).
  , copy :: CopyFn
  -- | Reads the selected project's title, if any.
  , title :: Effect (Nullable String)
  -- | Reads the absolute URL to share.
  , shareUrl :: Effect String
  }

type TopbarBindings =
  { -- | Share-button handler: native share when supported, else copy.
    onShare :: Effect Unit
  -- | Pixel-icon path data for the drawer/navigator button.
  , "NAV_ICON" :: Array String
  -- | Pixel-icon path data for the home link.
  , "HOME_ICON" :: Array String
  }

navIcon :: Array String
navIcon =
  [ "M18 5H19V6H18V5Z"
  , "M5 5H6V6H5V5Z"
  , "M18 18H19V19H18V18Z"
  , "M5 18H6V19H5V18Z"
  , "M9 17H8V7H9V17Z"
  , "M20 6H19V18H20V6Z"
  , "M18 5V4H6V5H18Z"
  , "M6 19V20H18V19H6Z"
  , "M5 6H4V18H5V6Z"
  ]

homeIcon :: Array String
homeIcon =
  [ "M11 5H13V6H11V5Z"
  , "M9 6H11V7H9V6Z"
  , "M13 6H15V7H13V6Z"
  , "M7 7H9V8H7V7Z"
  , "M15 7H17V8H15V7Z"
  , "M5 8H7V9H5V8Z"
  , "M17 8H19V9H17V8Z"
  , "M6 9H7V19H6V9Z"
  , "M17 9H18V19H17V9Z"
  , "M6 19H18V20H6V19Z"
  , "M11 14H13V19H11V14Z"
  ]

-- | Wires the topbar's share action — the native share sheet when
-- | supported, clipboard copy otherwise — and hands the template its
-- | pixel-icon path data.
setup :: TopbarArgs -> Effect TopbarBindings
setup args = do
  let
    onShare = do
      can <- read args.canShare
      url <- args.shareUrl
      if can then do
        title <- args.title
        runEffectFn4 shareWithFallbackImpl args.share args.copy title url
      else runEffectFn2 copyRunImpl args.copy url

  pure { onShare, "NAV_ICON": navIcon, "HOME_ICON": homeIcon }
