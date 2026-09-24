-- | Checks for the projects reader's pure faces: the topbar's `N / T`
-- | position count (absent with no selection), the share and theme
-- | buttons' labels and icons both ways, and the OG image's footer line;
-- | and the page's own rules — the route a slug names, the dek hidden when
-- | the article already opens with it, shelves grouped in order of first
-- | appearance and ordered newest first, arrow keys that step and wrap but
-- | leave modified keys and typing alone, and the SEO and OG text. Expected
-- | values were recorded from the original SFC templates or follow the
-- | module's documentation.
module Test.Components.Reader (suite) where

import Prelude

import App.Components.ReaderPage
  ( arrowStep
  , collapseWs
  , dekShown
  , groupByKey
  , ogFooterFor
  , ogKickerFor
  , routePathFor
  , seoTitleFor
  , siteUrlFor
  , sortShelvesBy
  , wrapIndex
  )
import App.Components.ReaderTopbar (countLabel, shareIconFor, shareLabelFor, themeLabelFor)
import App.Utils.ThemeIcon (themeIconFor)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect)

type Doc = { tag :: String, name :: String, date :: String }

doc :: String -> String -> String -> Doc
doc tag name date = { tag, name, date }

shelfKeys :: Array { key :: String, items :: Array Doc } -> Array String
shelfKeys = map _.key <<< sortShelvesBy _.date

suite :: Tally -> Effect Unit
suite t = do
  expect t "no selection shows no count" Nothing (toMaybe (countLabel (-1) 12))
  expect t "any negative index shows no count" Nothing (toMaybe (countLabel (-5) 12))
  expect t "the first project counts from one" (Just "1 / 12") (toMaybe (countLabel 0 12))
  expect t "the last project reads its own total" (Just "12 / 12") (toMaybe (countLabel 11 12))
  expect t "the count does not clamp to the total" (Just "4 / 3") (toMaybe (countLabel 3 3))
  expect t "a lone project reads 1 / 1" (Just "1 / 1") (toMaybe (countLabel 0 1))

  expect t "the share label before a copy" "Share this project" (shareLabelFor false)
  expect t "the share label after a copy" "Link copied" (shareLabelFor true)
  expect t "the share icon before a copy" "lucide:share-2" (shareIconFor false)
  expect t "the share icon after a copy" "lucide:check" (shareIconFor true)

  expect t "the theme label in light mode offers dark" "Switch to dark mode"
    (themeLabelFor false)
  expect t "the theme label in dark mode offers light" "Switch to light mode"
    (themeLabelFor true)
  expect t "the theme icon in light mode is the moon" "lucide:moon" (themeIconFor false)
  expect t "the theme icon in dark mode is the sun" "lucide:sun" (themeIconFor true)

  expect t "an empty shelf still reads as projects" "0 Projects" (ogFooterFor 0)
  expect t "one project is not singularized" "1 Projects" (ogFooterFor 1)
  expect t "the footer counts every project" "37 Projects" (ogFooterFor 37)

  expect t "the bare index names no project" Nothing (toMaybe (routePathFor []))
  expect t "a one-part slug names its project" (Just "/projects/chess")
    (toMaybe (routePathFor [ "chess" ]))
  expect t "a nested slug keeps its parts in order" (Just "/projects/courses/compilers")
    (toMaybe (routePathFor [ "courses", "compilers" ]))

  expect t "runs of whitespace collapse to one space, ends trimmed" "a b c"
    (collapseWs "  a \n\t b   c  ")
  expect t "empty text stays empty" "" (collapseWs "")

  expect t "a project with no summary has no dek" false (dekShown "" "Anything at all.")
  expect t "a summary the article does not open with shows" true
    (dekShown "A chess engine in Rust." "This started as a weekend experiment.")
  expect t "a summary the article opens with is hidden" false
    (dekShown "A compiler for Cool." "A compiler for Cool, written in OCaml over ten weeks.")
  expect t "the comparison ignores case" false
    (dekShown "A COMPILER for cool" "a compiler for Cool, written in OCaml.")
  expect t "the comparison ignores how whitespace runs" false
    (dekShown "A  compiler\nfor  Cool" "A compiler for\tCool, written in OCaml.")
  expect t "a trailing ellipsis on the summary is not compared" false
    (dekShown "A chess bot…" "A chess bot with alpha-beta search.")
  expect t "only the summary's first 40 characters are compared" false
    ( dekShown "Forty characters of shared opening text, then the summary wanders"
        "Forty characters of shared opening text, and then the article goes on."
    )
  expect t "a difference inside the first 40 characters shows the dek" true
    ( dekShown "Forty characters of shared opening text"
        "Forty characters of shared opening TEST, and more."
    )
  expect t "an article with no opening paragraph shows the dek" true
    (dekShown "A chess engine." "")

  let
    docs =
      [ doc "systems" "shell" "2022-03-01"
      , doc "games" "chess" "2023-05-01"
      , doc "systems" "compiler" "2021-01-01"
      , doc "web" "search" "2024-02-01"
      ]
    grouped = groupByKey _.tag docs
  expect t "shelves appear in the order their tag first does"
    [ "systems", "games", "web" ]
    (map _.key grouped)
  expect t "a shelf keeps its projects in their original order"
    [ [ "shell", "compiler" ], [ "chess" ], [ "search" ] ]
    (map (map _.name <<< _.items) grouped)
  expect t "no projects make no shelves" [] (map _.key (groupByKey _.tag ([] :: Array Doc)))

  expect t "shelves run newest first by their first project's date"
    [ "web", "games", "systems" ]
    (shelfKeys grouped)
  expect t "a shelf is dated by its first project, not its newest"
    [ "games", "systems" ]
    ( shelfKeys
        [ { key: "systems"
          , items: [ doc "systems" "a" "2021-01-01", doc "systems" "b" "2025-01-01" ]
          }
        , { key: "games", items: [ doc "games" "c" "2023-01-01" ] }
        ]
    )
  expect t "an empty shelf sorts last" [ "games", "empty" ]
    (shelfKeys [ { key: "empty", items: [] }, { key: "games", items: [ doc "games" "c" "2023" ] } ])
  expect t "shelves dated alike keep their order" [ "b", "a" ]
    ( shelfKeys
        [ { key: "b", items: [ doc "b" "x" "2023-01-01" ] }
        , { key: "a", items: [ doc "a" "y" "2023-01-01" ] }
        ]
    )

  expect t "stepping forward moves to the next project" 3 (wrapIndex 5 2 1)
  expect t "stepping back moves to the previous project" 1 (wrapIndex 5 2 (-1))
  expect t "stepping forward from the last wraps to the first" 0 (wrapIndex 5 4 1)
  expect t "stepping back from the first wraps to the last" 4 (wrapIndex 5 0 (-1))
  expect t "a lone project steps to itself" [ 0, 0 ] [ wrapIndex 1 0 1, wrapIndex 1 0 (-1) ]

  expect t "the right arrow steps forward" 1 (arrowStep "ArrowRight" false false)
  expect t "the left arrow steps back" (-1) (arrowStep "ArrowLeft" false false)
  expect t "other keys do not step" [ 0, 0, 0, 0 ]
    (map (\key -> arrowStep key false false) [ "ArrowUp", "ArrowDown", "Escape", "l" ])
  expect t "an arrow with a modifier held is left to the browser" [ 0, 0 ]
    [ arrowStep "ArrowRight" true false, arrowStep "ArrowLeft" true false ]
  expect t "an arrow typed in a field moves the caret, not the reader" [ 0, 0 ]
    [ arrowStep "ArrowRight" false true, arrowStep "ArrowLeft" false true ]

  expect t "the index's title" "Projects · Amittai Siavava" (seoTitleFor null)
  expect t "a project's title leads the page title" "Chess Bot · Projects · Amittai Siavava"
    (seoTitleFor (notNull "Chess Bot"))
  expect t "the OG kicker is the title-cased tag and the year"
    "Machine Learning · 2023"
    (ogKickerFor "machine learning" "2023-04-01T00:00:00.000Z")
  expect t "the OG kicker keeps minor words lowercase" "Systems and Compilers · 2021"
    (ogKickerFor "systems and compilers" "2021-11-30")
  expect t "the index's URL" "https://amittai.studio/projects" (siteUrlFor null)
  expect t "a project's URL" "https://amittai.studio/projects/chess"
    (siteUrlFor (notNull "/projects/chess"))
