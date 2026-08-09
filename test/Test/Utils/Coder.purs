-- | Golden cases for the transcoder and share-link codec, extracted from
-- | recordings of the original TypeScript implementation. The exact
-- | encoded strings are load-bearing: share URLs in the wild must keep
-- | decoding to the same text.
module Test.Utils.Coder (suite) where

import Prelude

import App.Utils.Coder (decodeShareText, encodeShareText, transcodeJs)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect)

-- "a\x{00A0}b" — the \x escape munches hex digits greedily, so the trailing
-- 'b' must stay outside the literal.
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

suite :: Tally -> Effect Unit
suite t = do
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
