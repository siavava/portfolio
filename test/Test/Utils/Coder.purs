-- | Golden cases for the transcoder and share-link codec, extracted from
-- | recordings of the original TypeScript implementation. The exact
-- | encoded strings are load-bearing: share URLs in the wild must keep
-- | decoding to the same text.
-- |
-- | Beyond the goldens: every output token points back at the input span
-- | that produced it (bytes of one character share that character's span,
-- | one decoded character spans all its byte tokens, separators point
-- | nowhere), preserved whitespace keeps newlines as newlines and spaces as
-- | `/`, parse errors name the first bad token (clipped past 24 characters)
-- | and yield nothing else, and share links are URL-safe base64 with no
-- | padding.
module Test.Utils.Coder (suite) where

import Prelude

import App.Utils.Coder (OutToken, codeFormats, decodeShareText, encodeShareText, transcodeJs)
import Data.Foldable (find, for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (toMaybe)
import Data.String (joinWith)
import Effect (Effect)
import Test.Harness (Tally, expect)

-- The \x escape munches hex digits greedily, so 'b' must stay outside the literal.
nbspInput :: String
nbspInput = "a\x00a0" <> "b"

type TranscodeCase =
  { label :: String
  , input :: String
  , from :: String
  , to :: String
  , preserveWhitespace :: Boolean
  , ok :: Boolean
  , error :: String
  , output :: String
  }

transcodeCases :: Array TranscodeCase
transcodeCases =
  [ { label: "letters→letters \"hello, world\""
    , input: "hello, world"
    , from: "letters"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "hello, world"
    }
  , { label: "letters→letters \"  leading and  double  spac (ws)"
    , input: "  leading and  double  spaces "
    , from: "letters"
    , to: "letters"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "  leading and  double  spaces "
    }
  , { label: "letters→binary \"hi\""
    , input: "hi"
    , from: "letters"
    , to: "binary"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "01101000 01101001"
    }
  , { label: "letters→binary \"hi yo\" (ws)"
    , input: "hi yo"
    , from: "letters"
    , to: "binary"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "01101000 01101001 / 01111001 01101111"
    }
  , { label: "letters→decimal \"hello, world\""
    , input: "hello, world"
    , from: "letters"
    , to: "decimal"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "104 101 108 108 111 44 32 119 111 114 108 100"
    }
  , { label: "letters→decimal \"naïve café — résumé\""
    , input: "naïve café — résumé"
    , from: "letters"
    , to: "decimal"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output:
        "110 97 195 175 118 101 32 99 97 102 195 169 32 226 128 148 32 114 195 169 115 117 109 195 169"
    }
  , { label: "letters→hex \"hi yo\" (ws)"
    , input: "hi yo"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "68 69 / 79 6f"
    }
  , { label: "letters→hex \"emoji 🎉 and 中文 mixed\""
    , input: "emoji 🎉 and 中文 mixed"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "65 6d 6f 6a 69 20 f0 9f 8e 89 20 61 6e 64 20 e4 b8 ad e6 96 87 20 6d 69 78 65 64"
    }
  , { label: "letters→hex \"\\t\\ttabbed\\tinput\" (ws)"
    , input: "\t\ttabbed\tinput"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "/ / 74 61 62 62 65 64 / 69 6e 70 75 74"
    }
  , { label: "binary→letters \"01101000 01101001\""
    , input: "01101000 01101001"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "hi"
    }
  , { label: "binary→letters \"0b01101000 0B01101001\""
    , input: "0b01101000 0B01101001"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "hi"
    }
  , { label: "binary→letters \"01101000 01101001 / 0111100 (ws)"
    , input: "01101000 01101001 / 01111001 01101111"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "hi yo"
    }
  , { label: "binary→letters \"hi\""
    , input: "hi"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: false
    , ok: false
    , error: "\"hi\" isn't binary — only 0 and 1"
    , output: ""
    }
  , { label: "binary→letters \"0110100\""
    , input: "0110100"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "4"
    }
  , { label: "binary→letters \"011010001\""
    , input: "011010001"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: false
    , ok: false
    , error: "\"011010001\" is 9 bits — use 8-bit groups"
    , output: ""
    }
  , { label: "binary→hex \"01101000 01101001\""
    , input: "01101000 01101001"
    , from: "binary"
    , to: "hex"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "68 69"
    }
  , { label: "binary→decimal \"01101000 01101001\""
    , input: "01101000 01101001"
    , from: "binary"
    , to: "decimal"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "104 105"
    }
  , { label: "binary→binary \"01101000 01101001\""
    , input: "01101000 01101001"
    , from: "binary"
    , to: "binary"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "01101000 01101001"
    }
  , { label: "decimal→letters \"104 101 108 108 111\""
    , input: "104 101 108 108 111"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "hello"
    }
  , { label: "decimal→letters \"999\""
    , input: "999"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: false
    , ok: false
    , error: "999 is out of byte range (0–255)"
    , output: ""
    }
  , { label: "decimal→letters \"104 / 105\" (ws)"
    , input: "104 / 105"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "h i"
    }
  , { label: "decimal→letters \"not-binary\""
    , input: "not-binary"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: false
    , ok: false
    , error: "\"not-binary\" isn't a decimal byte"
    , output: ""
    }
  , { label: "decimal→hex \"104 101 108 108 111\""
    , input: "104 101 108 108 111"
    , from: "decimal"
    , to: "hex"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "68 65 6c 6c 6f"
    }
  , { label: "decimal→binary \"104 101 108 108 111\""
    , input: "104 101 108 108 111"
    , from: "decimal"
    , to: "binary"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "01101000 01100101 01101100 01101100 01101111"
    }
  , { label: "decimal→decimal \"104 101 108 108 111\""
    , input: "104 101 108 108 111"
    , from: "decimal"
    , to: "decimal"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "104 101 108 108 111"
    }
  , { label: "hex→letters \"68 65 6c 6c 6f\""
    , input: "68 65 6c 6c 6f"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "hello"
    }
  , { label: "hex→letters \"68656c6c6f\""
    , input: "68656c6c6f"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "hello"
    }
  , { label: "hex→letters \"0x68 0X65\""
    , input: "0x68 0X65"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "he"
    }
  , { label: "hex→letters \"6865c\""
    , input: "6865c"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , ok: false
    , error: "\"6865c\" has an odd number of hex digits"
    , output: ""
    }
  , { label: "hex→letters \"not-binary\""
    , input: "not-binary"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , ok: false
    , error: "\"not-binary\" isn't hex"
    , output: ""
    }
  , { label: "hex→binary \"68 65 6c 6c 6f\""
    , input: "68 65 6c 6c 6f"
    , from: "hex"
    , to: "binary"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "01101000 01100101 01101100 01101100 01101111"
    }
  , { label: "hex→decimal \"68 65 6c 6c 6f\""
    , input: "68 65 6c 6c 6f"
    , from: "hex"
    , to: "decimal"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "104 101 108 108 111"
    }
  , { label: "hex→hex \"68 65 6c 6c 6f\""
    , input: "68 65 6c 6c 6f"
    , from: "hex"
    , to: "hex"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "68 65 6c 6c 6f"
    }
  , { label: "letters→binary \"a\\x00a0b\" (ws)"
    , input: nbspInput
    , from: "letters"
    , to: "binary"
    , preserveWhitespace: true
    , ok: true
    , error: ""
    , output: "01100001 / 01100010"
    }
  , { label: "letters→binary \"a\\x00a0b\""
    , input: nbspInput
    , from: "letters"
    , to: "binary"
    , preserveWhitespace: false
    , ok: true
    , error: ""
    , output: "01100001 11000010 10100000 01100010"
    }
  ]

type ByteCase =
  { input :: String
  , from :: String
  , to :: String
  , preserveWhitespace :: Boolean
  , bytes :: Array Int
  }

byteCases :: Array ByteCase
byteCases =
  [ { input: "hi yo"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: true
    , bytes: [ 104, 105, 121, 111 ]
    }
  , { input: "01101000 01101001"
    , from: "binary"
    , to: "letters"
    , preserveWhitespace: false
    , bytes: [ 104, 105 ]
    }
  , { input: "68 65 6c 6c 6f"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , bytes: [ 104, 101, 108, 108, 111 ]
    }
  ]

type ShareCase = { input :: String, encoded :: String }

shareCases :: Array ShareCase
shareCases =
  [ { input: "", encoded: "" }
  , { input: "hi yo", encoded: "aGkgeW8" }
  , { input: "hello, world", encoded: "aGVsbG8sIHdvcmxk" }
  , { input: "line one\nline two\n\nline four", encoded: "bGluZSBvbmUKbGluZSB0d28KCmxpbmUgZm91cg" }
  , { input: "naïve café — résumé", encoded: "bmHDr3ZlIGNhZsOpIOKAlCByw6lzdW3DqQ" }
  , { input: "emoji 🎉 and 中文 mixed", encoded: "ZW1vamkg8J-OiSBhbmQg5Lit5paHIG1peGVk" }
  , { input: "  leading and  double  spaces ", encoded: "ICBsZWFkaW5nIGFuZCAgZG91YmxlICBzcGFjZXMg" }
  , { input: "\t\ttabbed\tinput", encoded: "CQl0YWJiZWQJaW5wdXQ" }
  , { input: "01101000 01101001 / 01111001 01101111"
    , encoded: "MDExMDEwMDAgMDExMDEwMDEgLyAwMTExMTAwMSAwMTEwMTExMQ"
    }
  , { input: "not-binary", encoded: "bm90LWJpbmFyeQ" }
  ]

formatSamples :: Array { id :: String, sample :: String }
formatSamples =
  [ { id: "letters", sample: "hi" }
  , { id: "binary", sample: "01101000 01101001" }
  , { id: "decimal", sample: "104 105" }
  , { id: "hex", sample: "68 69" }
  ]

code :: String -> Int -> Int -> OutToken
code text srcStart srcEnd = { text, kind: "code", srcStart, srcEnd }

plain :: String -> Int -> Int -> OutToken
plain text srcStart srcEnd = { text, kind: "plain", srcStart, srcEnd }

sep :: OutToken
sep = plain " " (-1) (-1)

replacement :: String
replacement = "\xFFFD"

type TokenCase =
  { label :: String
  , input :: String
  , from :: String
  , to :: String
  , preserveWhitespace :: Boolean
  , tokens :: Array OutToken
  }

tokenCases :: Array TokenCase
tokenCases =
  [ { label: "each byte points at the letter it encodes"
    , input: "hi"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: false
    , tokens: [ code "68" 0 1, sep, code "69" 1 2 ]
    }
  , { label: "each letter points at the coded token it came from"
    , input: "68 69"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: false
    , tokens: [ code "h" 0 2, code "i" 3 5 ]
    }
  , { label: "both bytes of a two-byte letter point at that letter"
    , input: "é"
    , from: "letters"
    , to: "decimal"
    , preserveWhitespace: false
    , tokens: [ code "195" 0 1, sep, code "169" 0 1 ]
    }
  , { label: "a letter decoded from two byte tokens spans both"
    , input: "195 169"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: false
    , tokens: [ code "é" 0 7 ]
    }
  , { label: "an astral letter's four bytes span its two code units"
    , input: "🎉"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: false
    , tokens: [ code "f0" 0 2, sep, code "9f" 0 2, sep, code "8e" 0 2, sep, code "89" 0 2 ]
    }
  , { label: "an astral letter stays one letter token"
    , input: "a🎉"
    , from: "letters"
    , to: "letters"
    , preserveWhitespace: false
    , tokens: [ code "a" 0 1, code "🎉" 1 3 ]
    }
  , { label: "a preserved space becomes a / pointing at the space"
    , input: "a b"
    , from: "letters"
    , to: "binary"
    , preserveWhitespace: true
    , tokens: [ code "01100001" 0 1, sep, code "/" 1 2, sep, code "01100010" 2 3 ]
    }
  , { label: "a preserved newline stays a newline, with no separator around it"
    , input: "a\nb"
    , from: "letters"
    , to: "hex"
    , preserveWhitespace: true
    , tokens: [ code "61" 0 1, plain "\n" 1 2, code "62" 2 3 ]
    }
  , { label: "a preserved run of spaces between letters is one plain token"
    , input: "a  b"
    , from: "letters"
    , to: "letters"
    , preserveWhitespace: true
    , tokens: [ code "a" 0 1, plain "  " 1 3, code "b" 3 4 ]
    }
  , { label: "a coded newline decodes to a newline letter"
    , input: "68\n69"
    , from: "hex"
    , to: "letters"
    , preserveWhitespace: true
    , tokens: [ code "h" 0 2, plain "\n" 2 3, code "i" 3 5 ]
    }
  , { label: "trailing spaces before a coded newline leave no stray separator"
    , input: "68 69 \n6a"
    , from: "hex"
    , to: "hex"
    , preserveWhitespace: true
    , tokens: [ code "68" 0 2, sep, code "69" 3 5, plain "\n" 6 7, code "6a" 7 9 ]
    }
  , { label: "an invalid byte and the letter after it are separate letters"
    , input: "128 104"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: false
    , tokens: [ code replacement 0 3, code "h" 4 7 ]
    }
  , { label: "KNOWN BUG: a truncated two-byte lead swallows the letter after it into one token"
    , input: "195 104"
    , from: "decimal"
    , to: "letters"
    , preserveWhitespace: false
    , tokens: [ code (replacement <> "h") 0 7 ]
    }
  ]

type EdgeCase =
  { label :: String
  , input :: String
  , from :: String
  , to :: String
  , preserveWhitespace :: Boolean
  , ok :: Boolean
  , error :: String
  , output :: String
  , bytes :: Array Int
  }

edgeCase :: String -> String -> String -> String -> String -> Array Int -> EdgeCase
edgeCase label input from to output bytes =
  { label, input, from, to, preserveWhitespace: false, ok: true, error: "", output, bytes }

failCase :: String -> String -> String -> String -> EdgeCase
failCase label input from error =
  { label
  , input
  , from
  , to: "letters"
  , preserveWhitespace: false
  , ok: false
  , error
  , output: ""
  , bytes: []
  }

edgeCases :: Array EdgeCase
edgeCases =
  [ edgeCase "empty input is an empty success" "" "hex" "letters" "" []
  , edgeCase "whitespace-only coded input decodes to nothing" "  \t " "hex" "letters" "" []
  , (edgeCase "preserved whitespace-only letters stay as they are" "  " "letters" "letters" "  " [])
      { preserveWhitespace = true }
  , edgeCase "unpreserved spaces between letters are letters too" "a b" "letters" "decimal"
      "97 32 98"
      [ 97, 32, 98 ]
  , edgeCase "unpreserved newlines between coded tokens are dropped" "68\n69" "hex" "letters" "hi"
      [ 104, 105 ]
  , edgeCase "unpreserved / separators are dropped" "104 / 105" "decimal" "letters" "hi"
      [ 104, 105 ]
  , edgeCase "the decoded bytes do not depend on the output format" "é" "letters" "letters" "é"
      [ 195, 169 ]
  , edgeCase "255 is the largest decimal byte" "255" "decimal" "hex" "ff" [ 255 ]
  , edgeCase "0 is the smallest decimal byte" "0" "decimal" "binary" "00000000" [ 0 ]
  , edgeCase "leading zeros are fine in a decimal byte" "007" "decimal" "decimal" "7" [ 7 ]
  , edgeCase "a 16-bit binary run splits into two bytes" "0110100001101001" "binary" "letters"
      "hi"
      [ 104, 105 ]
  , edgeCase "a short binary token is one byte" "1" "binary" "decimal" "1" [ 1 ]
  , edgeCase "hex digits may be uppercase" "0xABCD" "hex" "decimal" "171 205" [ 171, 205 ]
  , edgeCase "binary output pads every byte to 8 bits" "\x01" "letters" "binary" "00000001"
      [ 1 ]
  , edgeCase "hex output pads every byte to 2 digits" "\x01" "letters" "hex" "01" [ 1 ]
  , edgeCase "an invalid byte decodes to the replacement character" "255" "decimal" "letters"
      replacement
      [ 255 ]
  , edgeCase "a lone lead byte decodes to the replacement character" "195" "decimal" "letters"
      replacement
      [ 195 ]
  , edgeCase "a truncated lead still keeps the next letter's text" "195 104" "decimal" "letters"
      (replacement <> "h")
      [ 195, 104 ]
  , edgeCase "an unknown source format reads as letters" "hi" "base64" "hex" "68 69" [ 104, 105 ]
  , edgeCase "an unknown target format writes letters" "68 69" "hex" "base64" "hi" [ 104, 105 ]
  , failCase "256 is out of byte range" "256" "decimal" "256 is out of byte range (0–255)"
  , failCase "a sign is not a decimal digit" "-1" "decimal" "\"-1\" isn't a decimal byte"
  , failCase "a bare 0b prefix is not binary" "0b" "binary" "\"0b\" isn't binary — only 0 and 1"
  , failCase "a 2 is not binary" "012" "binary" "\"012\" isn't binary — only 0 and 1"
  , failCase "a bare 0x prefix is not hex" "0x" "hex" "\"0x\" isn't hex"
  , failCase "the first bad token is the one reported" "68 zz 6" "hex" "\"zz\" isn't hex"
  , failCase "a 24-character token is quoted whole" "abcdefghijklmnopqrstuvwx" "decimal"
      "\"abcdefghijklmnopqrstuvwx\" isn't a decimal byte"
  , failCase "a longer token is clipped to 24 characters" "abcdefghijklmnopqrstuvwxyz" "decimal"
      "\"abcdefghijklmnopqrstuvwx…\" isn't a decimal byte"
  , failCase "a long bad bit run is clipped too" "0000000011111111000000001" "binary"
      "\"000000001111111100000000…\" is 25 bits — use 8-bit groups"
  ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "codeFormats · ids"
    [ "letters", "binary", "decimal", "hex" ]
    (map _.id codeFormats)
  expect t "codeFormats · labels equal ids" (map _.id codeFormats) (map _.label codeFormats)
  expect t "codeFormats · sample ids" (map _.id formatSamples) (map _.id codeFormats)
  for_ codeFormats \f -> do
    let
      sample = fromMaybe "" (_.sample <$> find (\s -> s.id == f.id) formatSamples)
      encoded = transcodeJs { input: "hi", from: "letters", to: f.id, preserveWhitespace: false }
      decoded = transcodeJs { input: sample, from: f.id, to: "letters", preserveWhitespace: false }
    expect t ("codeFormats · letters→" <> f.id <> " \"hi\"") sample encoded.output
    expect t ("codeFormats · " <> f.id <> "→letters · ok") true decoded.ok
    expect t ("codeFormats · " <> f.id <> "→letters · output") "hi" decoded.output
    expect t ("codeFormats · " <> f.id <> "→letters · bytes") [ 104, 105 ] decoded.bytes
  for_ transcodeCases \c -> do
    let
      r = transcodeJs
        { input: c.input, from: c.from, to: c.to, preserveWhitespace: c.preserveWhitespace }
    expect t (c.label <> " · ok") c.ok r.ok
    expect t (c.label <> " · error") c.error r.error
    expect t (c.label <> " · output") c.output r.output
  for_ byteCases \c -> do
    let
      r = transcodeJs
        { input: c.input, from: c.from, to: c.to, preserveWhitespace: c.preserveWhitespace }
    expect t (c.from <> "→" <> c.to <> " " <> show c.input <> " · bytes") c.bytes r.bytes
  for_ shareCases \c -> do
    expect t ("share " <> show c.input <> " · encoded") c.encoded (encodeShareText c.input)
    expect t ("share " <> show c.input <> " · round trip")
      (Just c.input)
      (toMaybe (decodeShareText c.encoded))
  expect t ("decode " <> show "aGVsbG8")
    (Just "hello")
    (toMaybe (decodeShareText "aGVsbG8"))
  expect t ("decode " <> show "not!!valid@@base64")
    (Nothing :: Maybe String)
    (toMaybe (decodeShareText "not!!valid@@base64"))

  for_ tokenCases \c -> do
    let
      r = transcodeJs
        { input: c.input, from: c.from, to: c.to, preserveWhitespace: c.preserveWhitespace }
    expect t ("tokens · " <> c.label) c.tokens r.tokens
    expect t ("tokens · " <> c.label <> " · output is the tokens' text")
      (joinWith "" (map _.text c.tokens))
      r.output

  for_ edgeCases \c -> do
    let
      r = transcodeJs
        { input: c.input, from: c.from, to: c.to, preserveWhitespace: c.preserveWhitespace }
    expect t (c.label <> " · ok") c.ok r.ok
    expect t (c.label <> " · error") c.error r.error
    expect t (c.label <> " · output") c.output r.output
    expect t (c.label <> " · bytes") c.bytes r.bytes
    unless c.ok (expect t (c.label <> " · no tokens") [] r.tokens)

  expect t "share links swap + for -" "fn5-" (encodeShareText "~~~")
  expect t "share links swap / for _" "Pz4_" (encodeShareText "?>?")
  expect t "share links drop the = padding" "YQ" (encodeShareText "a")
  expect t "a URL-safe share link decodes" (Just "?>?") (toMaybe (decodeShareText "Pz4_"))
  expect t "an unpadded share link decodes" (Just "a") (toMaybe (decodeShareText "YQ"))
