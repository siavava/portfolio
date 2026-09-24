-- | ## ContactPanel
-- |
-- | The setup composable behind `ContactPanel.vue`: the email button that
-- | reads "Email" at rest and reveals the address under the pointer, so
-- | the address is there to read without crowding the panel. The SFC
-- | keeps only the prop macro plus one call here.
module App.Components.ContactPanel
  ( ContactPanelArgs
  , ContactPanelBindings
  , setup
  ) where

import Prelude

import Effect (Effect)
import Vue (Computed, computed, read, ref, write)

type ContactPanelArgs =
  { -- | Reads the profile's email address.
    email :: Effect String
  }

type ContactPanelBindings =
  { -- | The button's `mailto:` link.
    href :: Computed String
  -- | The button's text: the address while hovered, "Email" otherwise.
  , label :: Computed String
  -- | Mouseenter handler: reveals the address.
  , enter :: Effect Unit
  -- | Mouseleave handler: puts "Email" back.
  , leave :: Effect Unit
  }

-- | Wires the email button's hover reveal and its `mailto:` link.
setup :: ContactPanelArgs -> Effect ContactPanelBindings
setup args = do
  hovering <- ref false
  href <- computed (("mailto:" <> _) <$> args.email)
  label <- computed do
    revealed <- read hovering
    if revealed then args.email else pure "Email"
  pure
    { href
    , label
    , enter: write hovering true
    , leave: write hovering false
    }
