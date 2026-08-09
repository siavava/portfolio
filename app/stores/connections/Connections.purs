-- | ## Connections
-- |
-- | Store core linking the bio copy to the interest map: bio targets
-- | announce node names on hover, map nodes register themselves, and the
-- | map lights the lineage to each known name. The pinia shell is
-- | `defineStore("connections", useConnectionsCore)`.
module App.Stores.Connections
  ( ConnectionsBindings
  , useConnectionsCore
  ) where

import Prelude

import Data.Array (filterA, null) as Array
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue
  ( ReactiveSet
  , Ref
  , reactiveSet
  , setAdd
  , setDelete
  , setHas
  , shallowRef
  , write
  )

-- | The connections store's public surface.
type ConnectionsBindings =
  { -- | Node names the map has registered.
    nodes :: ReactiveSet String
  , -- | Names whose lineage the map currently lights.
    activeNames :: Ref (Array String)
  , -- | Register a map node's name (on mount).
    registerNode :: EffectFn1 String Unit
  , -- | Drop a node name (on unmount).
    unregisterNode :: EffectFn1 String Unit
  , -- | Light the registered subset of the hovered names (a miss on every
    -- | name leaves the previous set lit).
    activate :: EffectFn1 (Array String) Unit
  , -- | Clear the lit names.
    deactivate :: Effect Unit
  }

-- | Assembles the connections store: the node registry and the
-- | active-name state the map's lineage highlight follows.
useConnectionsCore :: Effect ConnectionsBindings
useConnectionsCore = do
  nodes <- reactiveSet
  activeNames <- shallowRef ([] :: Array String)
  let
    activate names = do
      known <- Array.filterA (setHas nodes) names
      unless (Array.null known) (write activeNames known)

  pure
    { nodes
    , activeNames
    , registerNode: mkEffectFn1 (setAdd nodes)
    , unregisterNode: mkEffectFn1 (setDelete nodes)
    , activate: mkEffectFn1 activate
    , deactivate: write activeNames []
    }
