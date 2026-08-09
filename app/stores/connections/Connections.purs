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

type ConnectionsBindings =
  { nodes :: ReactiveSet String
  , activeNames :: Ref (Array String)
  , registerNode :: EffectFn1 String Unit
  , unregisterNode :: EffectFn1 String Unit
  , activate :: EffectFn1 (Array String) Unit
  , deactivate :: Effect Unit
  }

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
