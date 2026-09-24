-- | ## ReaderTopbar
-- |
-- | The setup composable behind `ReaderTopbar.vue`: the share action —
-- | native share with clipboard fallback — the share/theme button faces,
-- | the `N / T` position count, and the pixel-icon path data. The SFC
-- | keeps only the prop and emit macros plus one call here.
module App.Components.ReaderTopbar
  ( CopyFn
  , ShareFn
  , TopbarArgs
  , TopbarBindings
  , countLabel
  , setup
  , shareIconFor
  , shareLabelFor
  , themeLabelFor
  ) where

import Prelude

import App.Utils.ThemeIcon (themeIconFor)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Effect.Uncurried (EffectFn2, EffectFn4, runEffectFn2, runEffectFn4)
import Vue (Computed, computed, read)

-- | VueUse `useShare`'s `share` function.
foreign import data ShareFn :: Type

-- | VueUse `useClipboard`'s `copy` function.
foreign import data CopyFn :: Type

-- | VueUse `useShare()` — the share function and whether the platform
-- | has a native share sheet.
foreign import useShareImpl :: Effect { share :: ShareFn, isSupported :: Computed Boolean }

-- | VueUse `useClipboard({ copiedDuring: 1600 })` — the copy function
-- | and the flag that stays up for 1.6s after a copy.
foreign import useClipboardImpl :: Effect { copy :: CopyFn, copied :: Computed Boolean }

-- | Tries the native share sheet; on failure other than the user
-- | cancelling (AbortError), copies the URL instead.
foreign import shareWithFallbackImpl :: EffectFn4 ShareFn CopyFn (Nullable String) String Unit

-- | Copies the URL, promise discarded.
foreign import copyRunImpl :: EffectFn2 CopyFn String Unit

type TopbarArgs =
  { -- | Reads the selected project's title, if any.
    title :: Effect (Nullable String)
  -- | Reads the absolute URL to share.
  , shareUrl :: Effect String
  -- | Reads whether the page is in dark mode.
  , isDark :: Effect Boolean
  -- | Reads the selected project's index in reading order, -1 when absent.
  , index :: Effect Int
  -- | Reads how many projects are in reading order.
  , total :: Effect Int
  }

type TopbarBindings =
  { -- | Share-button handler: native share when supported, else copy.
    onShare :: Effect Unit
  -- | True for 1.6s after the link was copied — the button's `done` flash.
  , copied :: Computed Boolean
  -- | The share button's aria-label.
  , shareLabel :: Computed String
  -- | The share button's icon name.
  , shareIcon :: Computed String
  -- | The theme toggle's aria-label.
  , themeLabel :: Computed String
  -- | The theme toggle's icon name.
  , themeIcon :: Computed String
  -- | The `N / T` position count; null when no project is selected.
  , count :: Computed (Nullable String)
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

-- | The one-based `N / T` position of index `index` among `total`
-- | projects; null when the index is negative (no selection).
countLabel :: Int -> Int -> Nullable String
countLabel index total
  | index >= 0 = notNull (show (index + 1) <> " / " <> show total)
  | otherwise = null

-- | The share button's aria-label, by whether the link was just copied.
shareLabelFor :: Boolean -> String
shareLabelFor copied = if copied then "Link copied" else "Share this project"

-- | The share button's icon, by whether the link was just copied.
shareIconFor :: Boolean -> String
shareIconFor copied = if copied then "lucide:check" else "lucide:share-2"

-- | The theme toggle's aria-label, by whether the page is dark.
themeLabelFor :: Boolean -> String
themeLabelFor dark = if dark then "Switch to light mode" else "Switch to dark mode"

-- | Wires the topbar's share action — the native share sheet when
-- | supported, clipboard copy otherwise — derives the share and theme
-- | buttons' labels and icons and the position count, and hands the
-- | template its pixel-icon path data.
setup :: TopbarArgs -> Effect TopbarBindings
setup args = do
  { share, isSupported } <- useShareImpl
  { copy, copied } <- useClipboardImpl

  let
    onShare = do
      can <- read isSupported
      url <- args.shareUrl
      if can then do
        title <- args.title
        runEffectFn4 shareWithFallbackImpl share copy title url
      else runEffectFn2 copyRunImpl copy url

  shareLabel <- computed (shareLabelFor <$> read copied)
  shareIcon <- computed (shareIconFor <$> read copied)
  themeLabel <- computed (themeLabelFor <$> args.isDark)
  themeIcon <- computed (themeIconFor <$> args.isDark)
  count <- computed (countLabel <$> args.index <*> args.total)

  pure
    { onShare
    , copied
    , shareLabel
    , shareIcon
    , themeLabel
    , themeIcon
    , count
    , "NAV_ICON": navIcon
    , "HOME_ICON": homeIcon
    }
