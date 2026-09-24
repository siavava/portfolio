-- | ## Graph
-- |
-- | Pure traversal helpers for the interest map's link graph: an
-- | insertion-ordered adjacency list, reachability and lineage over it,
-- | tree-parent lookup, the endpoint test that gates a link on its nodes,
-- | and the entry stagger's reveal order. FFI-free and generic in the link
-- | type, so the logic is pure and testable in isolation. Only PureScript
-- | consumes it. @ts-internal
module App.Components.InterestMap.Graph
  ( AdjEntry
  , appearanceOrderBy
  , buildAdj
  , endpointsWithin
  , insertAdj
  , lineage
  , lookupAdj
  , parentOf
  , reachable
  ) where

import Prelude

import Data.Array (elem, find, findIndex, modifyAt, snoc, sortBy, uncons) as Array
import Data.Foldable (foldl)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, toMaybe)

-- | Insertion-ordered adjacency entries, one per source node.
type AdjEntry = { key :: String, vals :: Array String }

-- | Append `val` under `key`, creating the entry on first sight of `key`.
insertAdj :: String -> String -> Array AdjEntry -> Array AdjEntry
insertAdj key val entries = case Array.findIndex (\entry -> entry.key == key) entries of
  Just i -> fromMaybe entries
    (Array.modifyAt i (\entry -> entry { vals = Array.snoc entry.vals val }) entries)
  Nothing -> Array.snoc entries { key, vals: [ val ] }

-- | The values recorded under `key`, or `[]` when the key is absent.
lookupAdj :: Array AdjEntry -> String -> Array String
lookupAdj entries key = maybe [] _.vals (Array.find (\entry -> entry.key == key) entries)

-- | Every id reachable from `start` (inclusive) along the adjacency.
reachable :: Array AdjEntry -> String -> Array String
reachable adj start = go [] [ start ]
  where
  go seen frontier = case Array.uncons frontier of
    Nothing -> seen
    Just { head, tail } ->
      if Array.elem head seen then go seen tail
      else go (Array.snoc seen head) (tail <> lookupAdj adj head)

-- | Adjacency over an array of links, keyed by `keyOf` with `valOf`
-- | appended per link; links where either accessor is null are skipped.
buildAdj
  :: forall link
   . (link -> Nullable String)
  -> (link -> Nullable String)
  -> Array link
  -> Array AdjEntry
buildAdj keyOf valOf = foldl step []
  where
  step acc link = case toMaybe (keyOf link), toMaybe (valOf link) of
    Just key, Just val -> insertAdj key val acc
    _, _ -> acc

-- | The tree parent of a node — the source of the non-prereq link that
-- | targets it, read through the given target, prereq, and source
-- | accessors.
parentOf
  :: forall link
   . (link -> String)
  -> (link -> Boolean)
  -> (link -> Nullable String)
  -> Array link
  -> String
  -> Maybe String
parentOf targetOf prereqOf sourceOf links nodeId =
  Array.find (\link -> targetOf link == nodeId && not (prereqOf link)) links
    >>= \link -> toMaybe (sourceOf link)

-- | A node's whole lineage: everything reachable from it down the
-- | `children` adjacency, then everything reachable up the `parents` one
-- | — the node itself heading both halves.
lineage :: Array AdjEntry -> Array AdjEntry -> String -> Array String
lineage children parents nodeId = reachable children nodeId <> reachable parents nodeId

-- | Whether a link's endpoints all pass `has`: the target, and the source
-- | when the link has one (a center spoke has none).
endpointsWithin :: (String -> Boolean) -> String -> Nullable String -> Boolean
endpointsWithin has target source =
  has target
    && case toMaybe source of
      Nothing -> true
      Just from -> has from

-- | The entry stagger's reveal order: shallower levels first, and within
-- | a level by ascending shuffle key (ties keep their input order).
appearanceOrderBy :: forall node. (node -> Int) -> (node -> Number) -> Array node -> Array node
appearanceOrderBy levelOf keyOf nodes =
  map _.node $ Array.sortBy
    (\a b -> compare (levelOf a.node) (levelOf b.node) <> compare a.key b.key)
    (nodes <#> \node -> { node, key: keyOf node })
