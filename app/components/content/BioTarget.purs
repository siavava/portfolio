-- | ## BioTarget
-- |
-- | The setup composable behind `BioTarget.vue`: a phrase in the bio tied
-- | to one or more nodes of the interest map. Hovering it asks the
-- | connections store to light those nodes' lineage, and the phrase stays
-- | marked while any of its names is lit — including when the map lit it
-- | from another phrase. The SFC keeps only the prop macro and the
-- | connections-store handle plus one call here.
module App.Components.BioTarget
  ( BioTargetArgs
  , BioTargetBindings
  , litBy
  , setup
  , splitNames
  ) where

import Prelude

import Data.Array (filter)
import Data.Foldable (any, elem)
import Data.String (Pattern(..), split, trim)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, runEffectFn1)
import Vue (Computed, computed, read)

type BioTargetArgs =
  { -- | Reads the `node` prop: one or more map node names, comma-separated.
    node :: Effect String
  -- | Reads the connections store's `activeNames` — the names whose
  -- | lineage the map currently lights.
  , activeNames :: Effect (Array String)
  -- | The connections store's `activate`: lights the registered subset of
  -- | the given names.
  , activate :: EffectFn1 (Array String) Unit
  -- | The connections store's `deactivate`: clears the lit names.
  , deactivate :: Effect Unit
  }

type BioTargetBindings =
  { -- | Whether any of the phrase's names is lit on the map.
    isActive :: Computed Boolean
  -- | Mouseenter handler: lights the phrase's names on the map.
  , enter :: Effect Unit
  -- | Mouseleave handler: clears the map's lit names.
  , leave :: Effect Unit
  }

-- | The node names in a `node` prop: split on commas, trimmed, blanks
-- | dropped — so `"a, b,"` names `a` and `b`.
splitNames :: String -> Array String
splitNames node = filter (_ /= "") (map trim (split (Pattern ",") node))

-- | Whether any of the phrase's own names is among the lit ones.
litBy :: Array String -> Array String -> Boolean
litBy own active = any (_ `elem` active) own

-- | Parses the phrase's node names and ties its hover and highlight to the
-- | connections store.
setup :: BioTargetArgs -> Effect BioTargetBindings
setup args = do
  names <- computed (splitNames <$> args.node)
  isActive <- computed do
    own <- read names
    active <- args.activeNames
    pure (litBy own active)
  pure
    { isActive
    , enter: read names >>= runEffectFn1 args.activate
    , leave: args.deactivate
    }
