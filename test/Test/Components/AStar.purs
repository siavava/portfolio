-- | Golden cases for the A* visualizer's maze solvers, recorded from the
-- | pure pre-rewrite implementation.
module Test.Components.AStar (suite) where

import Prelude

import App.Components.AStarViz (draftMaze, greedyLen, neighborsOf, shortestPath)
import Data.Array (catMaybes, mapWithIndex, range, replicate, updateAt)
import Data.Foldable (foldl, for_)
import Data.Int (toNumber)
import Data.Int.Bits (zshr)
import Data.Maybe (Maybe(..), fromMaybe)
import Effect (Effect)
import Effect.Ref as Ref
import Test.Harness (Tally, expect)

emptyGrid :: Array Boolean
emptyGrid = replicate 220 false

-- | Column 20 walled top to bottom, cutting the goal column off entirely.
sealedGrid :: Array Boolean
sealedGrid =
  foldl (\walls r -> fromMaybe walls (updateAt (r * 22 + 20) true walls)) emptyGrid (range 0 9)

wallIndices :: Array Boolean -> Array Int
wallIndices = catMaybes <<< mapWithIndex (\i wall -> if wall then Just i else Nothing)

-- | The uint32 LCG the goldens were recorded with. PS `Int` math is
-- | 32-bit signed, so each step needs `zshr 0` to land back in unsigned
-- | range before scaling — same coercion idiom as the module's own
-- | seeded rng.
seededLcg :: Int -> Effect (Effect Number)
seededLcg seed = do
  state <- Ref.new seed
  pure do
    s <- Ref.read state
    let next = (s * 1664525 + 1013904223) `zshr` 0
    Ref.write next state
    pure (toNumber next / 4294967296.0)

seed42Walls :: Array Int
seed42Walls =
  [ 1
  , 3
  , 6
  , 12
  , 13
  , 14
  , 24
  , 27
  , 29
  , 35
  , 42
  , 45
  , 50
  , 53
  , 57
  , 64
  , 66
  , 72
  , 73
  , 74
  , 75
  , 76
  , 77
  , 79
  , 89
  , 90
  , 94
  , 98
  , 99
  , 101
  , 115
  , 116
  , 121
  , 123
  , 135
  , 138
  , 140
  , 141
  , 142
  , 143
  , 145
  , 148
  , 153
  , 160
  , 163
  , 167
  , 174
  , 179
  , 182
  , 186
  , 189
  , 190
  , 191
  , 192
  , 204
  , 212
  , 214
  ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "shortestPath empty" 26 (shortestPath emptyGrid)
  expect t "greedyLen empty" 26 (greedyLen emptyGrid)
  expect t "shortestPath sealed" (-1) (shortestPath sealedGrid)
  expect t "greedyLen sealed" (-1) (greedyLen sealedGrid)
  expect t "neighborsOf empty 0" [ 1, 22 ] (neighborsOf emptyGrid 0)
  expect t "neighborsOf empty 23" [ 22, 24, 1, 45 ] (neighborsOf emptyGrid 23)
  expect t "neighborsOf sealed 19" [ 18, 41 ] (neighborsOf sealedGrid 19)
  rng <- seededLcg 42
  draft <- draftMaze rng
  expect t "draftMaze seed 42 wall indices" seed42Walls (wallIndices draft)
  expect t "shortestPath seed 42 draft" (-1) (shortestPath draft)
  expect t "greedyLen seed 42 draft" (-1) (greedyLen draft)
  for_ [ 1, 2, 3, 7, 9 ] \seed -> do
    seededRng <- seededLcg seed
    maze <- draftMaze seededRng
    let optimal = shortestPath maze
    let greedy = greedyLen maze
    if optimal >= 0 then
      expect t ("greedy never beats optimal (seed " <> show seed <> ")") true (greedy >= optimal)
    else expect t ("greedy also unreachable (seed " <> show seed <> ")") (-1) greedy
