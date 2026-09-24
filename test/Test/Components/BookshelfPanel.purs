-- | Checks for the bookshelf panel's pure cores: the year a doc's date
-- | names (JavaScript's `Number` over its first four characters), the
-- | shelf ordering — featured first, then newest year, then title in
-- | locale order, with a year that cannot be read falling through to the
-- | title the way `b.year - a.year || …` did — and the project the card
-- | opens on, drawn from the featured projects whenever there are any.
module Test.Components.BookshelfPanel (suite) where

import Prelude

import App.Components.BookshelfPanel (byYear, seedFrom, shelve, yearOf)
import Data.Array (all)
import Data.Maybe (Maybe(..))
import Data.Number (isNaN, nan)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Book = { title :: String, year :: Number, featured :: Boolean }

book :: String -> Number -> Boolean -> Book
book title year featured = { title, year, featured }

catalog :: Array Book
catalog =
  [ book "Zeta" 2020.0 false
  , book "Beta" 2022.0 true
  , book "Gamma" 2024.0 false
  , book "Alpha" 2022.0 true
  , book "Delta" 2019.0 true
  ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "an ISO date names its year" 2023.0 (yearOf "2023-05-01T00:00:00.000Z")
  expect t "a bare year names itself" 2019.0 (yearOf "2019")
  expect t "a date that does not open with a year reads NaN" true (isNaN (yearOf "May 2023"))
  expect t "an empty date reads 0, as Number(\"\") does" 0.0 (yearOf "")

  expect t "a newer project sorts before an older one" LT
    (byYear (book "B" 2023.0 false) (book "A" 2021.0 false))
  expect t "an older project sorts after a newer one" GT
    (byYear (book "A" 2021.0 false) (book "B" 2023.0 false))
  expect t "within a year, titles sort alphabetically" LT
    (byYear (book "Alpha" 2022.0 false) (book "Beta" 2022.0 false))
  expect t "the same year and title tie" EQ
    (byYear (book "Alpha" 2022.0 false) (book "Alpha" 2022.0 false))
  expect t "titles compare by locale, not by code unit" LT
    (byYear (book "apple" 2022.0 false) (book "Banana" 2022.0 false))
  expect t "an unreadable year falls through to the title" LT
    (byYear (book "Alpha" nan false) (book "Beta" 2023.0 false))
  expect t "an unreadable year falls through either way round" GT
    (byYear (book "Beta" 2023.0 false) (book "Alpha" nan false))

  let shelf = shelve _.featured catalog
  expect t "the shelf runs featured first, each run newest then by title"
    [ "Alpha", "Beta", "Delta", "Gamma", "Zeta" ]
    (map _.title shelf)
  expect t "a featured project outranks a newer plain one" [ true, true, true, false, false ]
    (map _.featured shelf)
  expect t "with nothing featured the shelf is newest first"
    [ "Gamma", "Zeta" ]
    (map _.title (shelve _.featured [ book "Zeta" 2020.0 false, book "Gamma" 2024.0 false ]))
  expect t "an empty catalog shelves nothing" [] (map _.title (shelve _.featured []))

  expect t "the lowest roll opens on the first featured project" (Just "Alpha")
    (_.title <$> seedFrom _.featured shelf 0.0)
  expect t "a middling roll lands among the featured projects" (Just "Beta")
    (_.title <$> seedFrom _.featured shelf 0.5)
  expect t "the highest roll opens on the last featured project" (Just "Delta")
    (_.title <$> seedFrom _.featured shelf 0.999)
  expect t "no roll ever opens on a project that is not featured when some are" true
    ( all (\roll -> (_.featured <$> seedFrom _.featured shelf roll) == Just true)
        [ 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.99 ]
    )
  expect t "with nothing featured the whole catalog is the pool" (Just "Zeta")
    ( _.title <$> seedFrom _.featured
        [ book "Gamma" 2024.0 false, book "Zeta" 2020.0 false ]
        0.75
    )
  expect t "an empty catalog opens on nothing" Nothing
    (_.title <$> seedFrom _.featured ([] :: Array Book) 0.5)
