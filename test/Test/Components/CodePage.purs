-- | Checks for the `/code` page's pure template helpers: byte chips (hex
-- | text and hover title), the ribbon's overflow label at and around its
-- | cap, the unit and placeholder per format, the share and copy button
-- | states, the swap rotation, the share-link seeding of formats and the
-- | whitespace toggle, the caret-to-token highlight test and the set it
-- | builds, the output footer's summary, and the decorative bit strip.
-- | Expected values were recorded by evaluating the original template
-- | expressions and TypeScript helpers in bun, or follow the module's
-- | documentation.
module Test.Components.CodePage (suite) where

import Prelude

import App.Components.CodePage
  ( OutToken
  , bitstripFor
  , byteHex
  , byteTitle
  , chipTabindexFor
  , copyDisabledFor
  , copyLabelFor
  , formatPlaceholder
  , hotIndex
  , hotIndices
  , moreBytesLabel
  , outPlaceholderFor
  , seedFormat
  , seedPreserve
  , shareLinkLabelFor
  , shareTitleFor
  , swapTransform
  , unitName
  , unitsSummary
  )
import Data.Array (all, filter, length)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Data.String (Pattern(..), split)
import Data.String.CodeUnits as CU
import Effect (Effect)
import Test.Harness (Tally, expect)

codeTok :: Int -> Int -> OutToken
codeTok srcStart srcEnd = { text: "01101000", kind: "code", srcStart, srcEnd }

suite :: Tally -> Effect Unit
suite t = do
  expect t "byte chips are two lowercase hex digits"
    [ "00", "01", "0a", "0f", "10", "7f", "ff" ]
    (map byteHex [ 0, 1, 10, 15, 16, 127, 255 ])

  expect t "a printable byte's title shows its glyph" "h  dec 104  bin 01101000" (byteTitle 104)
  expect t "a space is printable" "   dec 32  bin 00100000" (byteTitle 32)
  expect t "a tilde is the last printable byte" "~  dec 126  bin 01111110" (byteTitle 126)
  expect t "DEL shows a middle dot" "·  dec 127  bin 01111111" (byteTitle 127)
  expect t "a newline shows a middle dot" "·  dec 10  bin 00001010" (byteTitle 10)
  expect t "the byte just below space is a control byte" "·  dec 31  bin 00011111"
    (byteTitle 31)
  expect t "a null byte pads to eight binary digits" "·  dec 0  bin 00000000" (byteTitle 0)
  expect t "a high byte is not printable" "·  dec 255  bin 11111111" (byteTitle 255)

  expect t "an empty ribbon has no overflow label" Nothing (toMaybe (moreBytesLabel 160 0))
  expect t "one byte under the cap has no overflow label" Nothing (toMaybe (moreBytesLabel 160 159))
  expect t "a ribbon exactly at the cap has no overflow label" Nothing
    (toMaybe (moreBytesLabel 160 160))
  expect t "one byte past the cap is one more" (Just "+1 more") (toMaybe (moreBytesLabel 160 161))
  expect t "the label counts every hidden byte" (Just "+40 more") (toMaybe (moreBytesLabel 160 200))

  expect t "each target format counts in its own unit"
    [ "chars", "bits", "bytes", "nibbles" ]
    (map unitName [ "letters", "binary", "decimal", "hex" ])
  expect t "an unknown format counts bytes" "bytes" (unitName "octal")
  expect t "each source format has its own placeholder"
    [ "type anything…", "01101000 01101001 …", "104 101 108 …", "68 65 6c 6c 6f …" ]
    (map formatPlaceholder [ "letters", "binary", "decimal", "hex" ])
  expect t "an unknown format gets the free-text placeholder" "type anything…"
    (formatPlaceholder "octal")

  expect t "nothing to share while the input is empty or blank"
    [ "nothing to share yet", "nothing to share yet", "nothing to share yet" ]
    (map shareTitleFor [ "", "   ", " \n\t" ])
  expect t "JS trim also strips no-break, line-separator and BOM spaces"
    [ "nothing to share yet", "nothing to share yet", "nothing to share yet" ]
    (map shareTitleFor [ "\x00a0", "\x2028", "\xfeff" ])
  expect t "any visible text can be shared"
    [ "copy a link to this exact conversion", "copy a link to this exact conversion" ]
    (map shareTitleFor [ "x", "  a  " ])

  expect t "the swap turns half a revolution per click"
    [ "rotate(0deg)", "rotate(180deg)", "rotate(540deg)" ]
    (map swapTransform [ 0, 1, 3 ])

  expect t "copy is off with no output" true (copyDisabledFor "" "")
  expect t "copy is on with output and no error" false (copyDisabledFor "x" "")
  expect t "copy is off while an error shows" true (copyDisabledFor "x" "err")
  expect t "copy is off on an error with no output" true (copyDisabledFor "" "err")

  expect t "a known format in the link is kept" "hex" (seedFormat "letters" (notNull "hex"))
  expect t "a missing format param falls back" "binary" (seedFormat "binary" null)
  expect t "an unknown format param falls back" "letters" (seedFormat "letters" (notNull "octal"))
  expect t "format ids are case-sensitive" "letters" (seedFormat "letters" (notNull "HEX"))
  expect t "whitespace is preserved without a ws param" true (seedPreserve null)
  expect t "ws=0 drops whitespace" false (seedPreserve (notNull "0"))
  expect t "any other ws value preserves whitespace" [ true, true ]
    (map seedPreserve [ notNull "1", notNull "" ])

  expect t "a caret inside a code token lights it" (Just 2) (toMaybe (hotIndex 5 2 (codeTok 4 8)))
  expect t "a caret at a token's start lights it" (Just 0) (toMaybe (hotIndex 4 0 (codeTok 4 8)))
  expect t "a caret at the span's end, after its last char, lights it" (Just 1)
    (toMaybe (hotIndex 8 1 (codeTok 4 8)))
  expect t "a caret beyond the token leaves it dark" Nothing (toMaybe (hotIndex 9 1 (codeTok 4 8)))
  expect t "a caret before the token leaves it dark" Nothing (toMaybe (hotIndex 3 1 (codeTok 4 8)))
  expect t "a token with no source span never lights" Nothing
    (toMaybe (hotIndex 0 1 (codeTok (-1) 3)))
  expect t "plain runs never light" Nothing
    (toMaybe (hotIndex 5 1 { text: " ", kind: "plain", srcStart: 4, srcEnd: 8 }))

  let
    toks =
      [ codeTok 0 3
      , { text: " ", kind: "plain", srcStart: 3, srcEnd: 4 }
      , codeTok 4 8
      , codeTok 8 12
      ]
  expect t "no caret recorded lights nothing" [] (hotIndices (-1) toks)
  expect t "a caret inside one token lights just that one" [ 2 ] (hotIndices 5 toks)
  expect t "a caret on a boundary two spans share lights both" [ 2, 3 ] (hotIndices 8 toks)
  expect t "a caret on a plain run lights only the code it touches" [ 0 ] (hotIndices 3 toks)
  expect t "a caret past every span lights nothing" [] (hotIndices 20 toks)
  expect t "no tokens light nothing" [] (hotIndices 5 [])

  expect t "binary output counts eight bits a byte" "16 bits · 2 bytes" (unitsSummary "binary" 2)
  expect t "hex output counts two nibbles a byte" "4 nibbles · 2 bytes" (unitsSummary "hex" 2)
  expect t "decimal output counts bytes" "3 bytes · 3 bytes" (unitsSummary "decimal" 3)
  expect t "empty output counts nothing" "0 bits · 0 bytes" (unitsSummary "binary" 0)

  expect t "the try chips are tabbable until the input is used" 0 (chipTabindexFor false)
  expect t "the try chips leave the tab order once the input is used" (-1)
    (chipTabindexFor true)
  expect t "the share button before and after a copied link" [ "share ⇗", "link copied" ]
    (map shareLinkLabelFor [ false, true ])
  expect t "the copy button before and after a copy" [ "copy", "copied" ]
    (map copyLabelFor [ false, true ])
  expect t "the output placeholder without an error" "output" (outPlaceholderFor "")
  expect t "the output placeholder is a dash on an error" "—" (outPlaceholderFor "bad digit")

  let
    strip = bitstripFor "hello"
    groups = filter (_ /= "") (split (Pattern " ") strip)
  expect t "the bit strip is twelve space-separated bytes" 12 (length groups)
  expect t "each byte of the strip is eight digits" true (all (\g -> CU.length g == 8) groups)
  expect t "the strip is only binary digits" true
    (all (\c -> c == '0' || c == '1' || c == ' ') (CU.toCharArray strip))
  expect t "the strip is the same for the same input" strip (bitstripFor "hello")
  expect t "an empty input strips as the word code" (bitstripFor "code") (bitstripFor "")
  expect t "different inputs strip differently" true (bitstripFor "hello" /= bitstripFor "world")
