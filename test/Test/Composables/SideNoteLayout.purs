-- | Checks for the margin-note placement: notes group by positioning
-- | parent in the order the parents are first seen, without reordering
-- | the notes inside a group; within a group each visible note sits at
-- | its trigger's offset unless the visible note above would overlap it,
-- | in which case it drops to 16px below that note's foot; hidden notes
-- | keep their offset and never push the notes after them.
module Test.Composables.SideNoteLayout (suite) where

import Prelude

import App.Composables.SideNoteLayout (groupsOf, stackNote)
import Data.Array (concat, foldl, snoc)
import Data.Number (infinity)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Note = { visible :: Boolean, desired :: Number, height :: Number }

note :: Boolean -> Number -> Number -> Note
note visible desired height = { visible, desired, height }

tops :: Array Note -> Array Number
tops notes = (foldl step { floor: negate infinity, out: [] } notes).out
  where
  step acc next =
    let
      placed = stackNote acc.floor next
    in
      { floor: placed.floor, out: snoc acc.out placed.top }

tagged :: Int -> String -> { group :: Int, name :: String }
tagged group name = { group, name }

names :: Array (Array { group :: Int, name :: String }) -> Array (Array String)
names = map (map _.name)

suite :: Tally -> Effect Unit
suite t = do
  expect t "groupsOf: no notes, no groups" [] (names (groupsOf []))
  expect t "groupsOf: one parent is one group in registration order"
    [ [ "b", "a", "c" ] ]
    (names (groupsOf [ tagged 0 "b", tagged 0 "a", tagged 0 "c" ]))
  expect t "groupsOf: parents appear in first-seen order, not by number"
    [ [ "a", "c" ], [ "b", "d" ], [ "e" ] ]
    ( names
        ( groupsOf
            [ tagged 1 "a", tagged 0 "b", tagged 1 "c", tagged 0 "d", tagged 2 "e" ]
        )
    )
  expect t "groupsOf: every note lands in exactly one group"
    [ "a", "c", "b", "d", "e" ]
    ( map _.name
        (concat (groupsOf [ tagged 3 "a", tagged 1 "b", tagged 3 "c", tagged 1 "d", tagged 7 "e" ]))
    )

  expect t "stackNote: the first visible note sits at its trigger, even above the parent"
    { top: -20.0, floor: 26.0 }
    (stackNote (negate infinity) (note true (-20.0) 30.0))
  expect t "stackNote: a visible note below the floor keeps its offset"
    { top: 150.0, floor: 196.0 }
    (stackNote 100.0 (note true 150.0 30.0))
  expect t "stackNote: a visible note above the floor drops to it"
    { top: 100.0, floor: 146.0 }
    (stackNote 100.0 (note true 40.0 30.0))
  expect t "stackNote: a visible note exactly at the floor stays put"
    { top: 100.0, floor: 146.0 }
    (stackNote 100.0 (note true 100.0 30.0))
  expect t "stackNote: a hidden note keeps its offset and leaves the floor alone"
    { top: 40.0, floor: 100.0 }
    (stackNote 100.0 (note false 40.0 30.0))
  expect t "stackNote: a hidden note under an open floor keeps its offset"
    { top: 5.0, floor: negate infinity }
    (stackNote (negate infinity) (note false 5.0 30.0))

  expect t "stack: notes far enough apart all sit at their triggers"
    [ 0.0, 100.0, 300.0 ]
    (tops [ note true 0.0 50.0, note true 100.0 50.0, note true 300.0 10.0 ])
  expect t "stack: a note exactly one gap below the last foot does not move"
    [ 0.0, 66.0 ]
    (tops [ note true 0.0 50.0, note true 66.0 10.0 ])
  expect t "stack: overlapping notes cascade 16px below each other's feet"
    [ 0.0, 66.0, 122.0 ]
    (tops [ note true 0.0 50.0, note true 20.0 40.0, note true 30.0 10.0 ])
  expect t "stack: a hidden note in the middle neither moves nor pushes"
    [ 0.0, 66.0, 30.0, 122.0 ]
    ( tops
        [ note true 0.0 50.0
        , note true 20.0 40.0
        , note false 30.0 500.0
        , note true 40.0 10.0
        ]
    )
  expect t "stack: a hidden first note leaves the next visible note at its trigger"
    [ 0.0, 10.0 ]
    (tops [ note false 0.0 50.0, note true 10.0 10.0 ])
