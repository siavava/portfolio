-- | Checks for the site's share card wording: the profile's kicker, name
-- | and description over a shelf of every project, blank until the
-- | profile loads and empty until the count does — and each field a
-- | getter that follows the queries as they resolve.
module Test.Components.Site (suite) where

import Prelude

import App.Components.Site (ShelfProfile, shelfCard)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Effect.Ref as Ref
import Test.Harness (Tally, expect)

profile :: ShelfProfile
profile =
  { name: "Amittai Siavava"
  , og: { kicker: "Portfolio", description: "Things built, written and drawn." }
  }

suite :: Tally -> Effect Unit
suite t = do
  loadedProfile <- Ref.new (null :: Nullable ShelfProfile)
  loadedCount <- Ref.new (null :: Nullable Int)
  let
    card = shelfCard
      { profile: Ref.read loadedProfile, projectCount: Ref.read loadedCount }

  kicker <- card.kicker
  title <- card.title
  description <- card.description
  expect t "until the profile loads, the card's words are blank" [ "", "", "" ]
    [ kicker, title, description ]
  footer <- card.footer
  total <- card.total
  expect t "until the count loads, the shelf is empty" 0 total
  expect t "until the count loads, the footer counts none" "0 Projects" footer

  Ref.write (notNull profile) loadedProfile
  kicker' <- card.kicker
  title' <- card.title
  description' <- card.description
  expect t "the card's kicker is the profile's og kicker" "Portfolio" kicker'
  expect t "the card's title is the profile's name" "Amittai Siavava" title'
  expect t "the card's description is the profile's og description"
    "Things built, written and drawn."
    description'

  Ref.write (notNull 12) loadedCount
  footer' <- card.footer
  total' <- card.total
  expect t "the shelf holds every project" 12 total'
  expect t "the footer counts the projects under the shelf" "12 Projects" footer'
