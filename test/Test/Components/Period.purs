-- | Checks for one period of a year: it is the spotlit or hot period when a
-- | spot names where it began and where it ended — so periods opening in
-- | the same month stay apart — never when either side is missing, and it
-- | reads as a range only when it runs over more than one month.
module Test.Components.Period (suite) where

import Prelude

import App.Components.Period (Spot, folding, isPeriodAt, spansMonths)
import App.Components.Timeline (PeriodInfo, periodInfo)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

summer :: PeriodInfo
summer =
  { year: 2024
  , month: 6
  , endYear: 2024
  , endMonth: 9
  , months: 4
  , label: "jun – sep"
  , spoken: "June to September"
  }

spot :: Int -> Int -> Int -> Int -> Nullable Spot
spot year month endYear endMonth = notNull { year, month, endYear, endMonth }

suite :: Tally -> Effect Unit
suite t = do
  expect t "a spot on the period's start and end names it" true
    (isPeriodAt (spot 2024 6 2024 9) (notNull summer))
  expect t "a spot on another start month does not" false
    (isPeriodAt (spot 2024 7 2024 9) (notNull summer))
  expect t "the same months of another year do not" false
    (isPeriodAt (spot 2023 6 2023 9) (notNull summer))
  expect t "a period opening the same month but ending elsewhere is another period" false
    (isPeriodAt (spot 2024 6 2024 11) (notNull summer))
  expect t "no spot names no period" false (isPeriodAt null (notNull summer))
  expect t "an unreadable period is never named" false (isPeriodAt (spot 2024 6 2024 9) null)
  expect t "a run past New Year is named by both its years" true
    (isPeriodAt (spot 2024 11 2025 2) (periodInfo 2024 "Nov" (notNull "Feb")))
  expect t "a single month read from its props ends where it starts" true
    (isPeriodAt (spot 2024 6 2024 6) (periodInfo 2024 "June" null))

  expect t "a four-month period is a range" true (spansMonths (notNull summer))
  expect t "a single month is not a range" false (spansMonths (notNull summer { months = 1 }))
  expect t "an unreadable period is not a range" false (spansMonths null)
  expect t "a period written with only a start is not a range" false
    (spansMonths (periodInfo 2024 "Jun" null))
  expect t "a period written from and to is a range" true
    (spansMonths (periodInfo 2024 "Jun" (notNull "Sep")))

  expect t "a period with more than a headline folds where periods fold" true
    (folding (notNull [ "2023-9-2024-3", "2024-8-2026-7" ]) (notNull "2024-8-2026-7"))
  expect t "a period that is all headline never folds" false
    (folding (notNull [ "2023-9-2024-3" ]) (notNull "2024-6-2024-6"))
  expect t "nothing folds where periods are not folded" false
    (folding null (notNull "2024-8-2026-7"))
  expect t "an unreadable period never folds" false
    (folding (notNull [ "2024-8-2026-7" ]) null)
