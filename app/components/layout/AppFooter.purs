-- | ## AppFooter
-- |
-- | The setup composable behind `AppFooter.vue`: the client-mount flag and
-- | the hover-delayed past-versions popover. The SFC keeps only the prop
-- | macro and color-mode glue plus one call here.
module App.Components.AppFooter
  ( FooterBindings
  , useAppFooter
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Vue (Ref, onMounted, onUnmounted, ref, write)

type FooterBindings =
  { mounted :: Ref Boolean
  , showVersions :: Ref Boolean
  , openVersions :: Effect Unit
  , closeVersions :: Effect Unit
  }

useAppFooter :: Effect FooterBindings
useAppFooter = do
  mounted <- ref false
  onMounted (write mounted true)

  showVersions <- ref false
  closeTimer <- Ref.new (Nothing :: Maybe TimeoutId)

  let
    clearClose = Ref.read closeTimer >>= case _ of
      Just pending -> clearTimeout pending *> Ref.write Nothing closeTimer
      Nothing -> pure unit

    openVersions = clearClose *> write showVersions true

    closeVersions = do
      clearClose
      pending <- setTimeout 300 (write showVersions false)
      Ref.write (Just pending) closeTimer

  onUnmounted clearClose

  pure { mounted, showVersions, openVersions, closeVersions }
