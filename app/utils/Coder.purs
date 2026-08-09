-- | ## Coder
-- |
-- | Pure conversion engine behind `/code`, ported from TypeScript: transcodes
-- | text between letters (plain UTF-8 text), binary, decimal, and hex byte
-- | representations, any direction. Everything round-trips through a segment
-- | list — runs of bytes interleaved with (optionally preserved) whitespace —
-- | and every output token carries the input character span that produced it,
-- | so the UI can highlight where the cursor lands on the other side.
-- |
-- | `app/utils/coder.ts` is a thin typed shim over `transcodeJs`; the platform
-- | edges (UTF-8 codecs, base64) live in the FFI companion `Coder.js`.
module App.Utils.Coder
  ( CodeFormat(..)
  , OutToken
  , TranscodeJs
  , transcodeJs
  , encodeShareText
  , decodeShareText
  ) where

import Prelude

import Data.Array (catMaybes, concatMap, index, last, length, mapWithIndex, slice, snoc)
import Data.Either (Either(..))
import Data.Foldable (all, foldM, foldl)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Monoid (power)
import Data.Nullable (Nullable)
import Data.String (Pattern(..), joinWith, split, toLower)
import Data.String.CodeUnits as CU

foreign import utf8EncodeImpl :: String -> Array Int
foreign import utf8DecodeImpl :: Array Int -> String
foreign import codePointStringsImpl :: String -> Array String

-- | base64url-encode arbitrary text for share links.
foreign import encodeShareText :: String -> String

-- | Decode a share-link payload; null if malformed.
foreign import decodeShareText :: String -> Nullable String

data CodeFormat = Letters | Binary | Decimal | Hex

derive instance eqCodeFormat :: Eq CodeFormat

parseFormat :: String -> CodeFormat
parseFormat "binary" = Binary
parseFormat "decimal" = Decimal
parseFormat "hex" = Hex
parseFormat _ = Letters

-- | Input character span [start, end) in code units, mirroring JS indices.
type Span = { start :: Int, end :: Int }

-- | One rendered piece of output. `code` tokens map back to input chars.
type OutToken = { text :: String, kind :: String, srcStart :: Int, srcEnd :: Int }

data Segment
  = BytesSeg (Array Int) (Array Span)
  | WsSeg String Int Int

segBytes :: Segment -> Array Int
segBytes (BytesSeg bytes _) = bytes
segBytes _ = []

-- character classes ------------------------------------------------------

isWsChar :: Char -> Boolean
isWsChar c = c == ' ' || c == '\t' || c == '\n' || c == '\r'

isSpaceTab :: Char -> Boolean
isSpaceTab c = c == ' ' || c == '\t'

isBinaryChar :: Char -> Boolean
isBinaryChar c = c == '0' || c == '1'

isDigitChar :: Char -> Boolean
isDigitChar c = c >= '0' && c <= '9'

isHexChar :: Char -> Boolean
isHexChar c = isDigitChar c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

-- small string helpers ---------------------------------------------------

clip :: String -> String
clip s = if CU.length s > 24 then CU.take 24 s <> "…" else s

chunkStr :: Int -> String -> Array String
chunkStr size = go []
  where
  go acc rest
    | CU.length rest == 0 = acc
    | otherwise = go (snoc acc (CU.take size rest)) (CU.drop size rest)

stripPrefixCi :: String -> String -> String
stripPrefixCi prefix s = if toLower (CU.take 2 s) == prefix then CU.drop 2 s else s

allChars :: (Char -> Boolean) -> String -> Boolean
allChars p s = all p (CU.toCharArray s)

padZeros :: Int -> String -> String
padZeros width s = power "0" (max 0 (width - CU.length s)) <> s

endsWithWs :: String -> Boolean
endsWithWs s = case CU.charAt (CU.length s - 1) s of
  Just c -> isWsChar c
  Nothing -> false

-- | Split a string into alternating runs classified by `isWs`, with
-- | code-unit start offsets — the pure replacement for regex scanning.
type Run = { isWs :: Boolean, text :: String, start :: Int }

splitRunsBy :: (Char -> Boolean) -> String -> Array Run
splitRunsBy p s = finish (foldl step { runs: [], current: Nothing, pos: 0 } (CU.toCharArray s))
  where
  step st ch =
    let
      ws = p ch
      chStr = CU.singleton ch
    in
      case st.current of
        Just cur
          | cur.isWs == ws ->
              st { current = Just (cur { text = cur.text <> chStr }), pos = st.pos + 1 }
          | otherwise ->
              { runs: snoc st.runs cur, current: Just { isWs: ws, text: chStr, start: st.pos }, pos: st.pos + 1 }
        Nothing ->
          st { current = Just { isWs: ws, text: chStr, start: st.pos }, pos = st.pos + 1 }
  finish st = case st.current of
    Just cur -> snoc st.runs cur
    Nothing -> st.runs

-- decoding ---------------------------------------------------------------

-- | Parse one coded token (no whitespace) into bytes, or an error string.
tokenToBytes :: CodeFormat -> String -> Either String (Array Int)
tokenToBytes Binary token =
  let
    t = stripPrefixCi "0b" token
  in
    if t == "" || not (allChars isBinaryChar t) then
      Left ("\"" <> clip token <> "\" isn't binary — only 0 and 1")
    else if CU.length t `mod` 8 == 0 then
      Right (map (parseRadix Int.binary) (chunkStr 8 t))
    else if CU.length t < 8 then
      Right [ parseRadix Int.binary t ]
    else
      Left ("\"" <> clip token <> "\" is " <> show (CU.length t) <> " bits — use 8-bit groups")
tokenToBytes Hex token =
  let
    t = stripPrefixCi "0x" token
  in
    if t == "" || not (allChars isHexChar t) then
      Left ("\"" <> clip token <> "\" isn't hex")
    else if CU.length t `mod` 2 == 1 then
      Left ("\"" <> clip token <> "\" has an odd number of hex digits")
    else
      Right (map (parseRadix Int.hexadecimal) (chunkStr 2 t))
tokenToBytes _ token =
  if not (allChars isDigitChar token) then
    Left ("\"" <> clip token <> "\" isn't a decimal byte")
  else case Int.fromString token of
    Just n | n <= 255 -> Right [ n ]
    _ -> Left (token <> " is out of byte range (0–255)")

parseRadix :: Int.Radix -> String -> Int
parseRadix radix s = fromMaybe 0 (Int.fromStringAs radix s)

-- | UTF-8 encode `text`, giving every byte the char span it came from.
textToByteSegment :: Int -> String -> Segment
textToByteSegment offset text = BytesSeg st.bytes st.spans
  where
  st = foldl step { bytes: [], spans: [], pos: 0 } (codePointStringsImpl text)
  step acc ch =
    let
      encoded = utf8EncodeImpl ch
      chLen = CU.length ch
      span = { start: offset + acc.pos, end: offset + acc.pos + chLen }
    in
      { bytes: acc.bytes <> encoded, spans: acc.spans <> map (const span) encoded, pos: acc.pos + chLen }

-- | Scanner items for coded-format input: tokens and preserved whitespace.
data Item = NewlineItem Int | SlashItem Int | TokenItem String Int

codedItems :: Boolean -> String -> Array Item
codedItems preserve input = st.items
  where
  st = foldl perLine { items: [], lineStart: 0, li: 0 } (split (Pattern "\n") input)
  perLine acc line =
    let
      withNewline =
        if acc.li > 0 && preserve then snoc acc.items (NewlineItem (acc.lineStart - 1))
        else acc.items
      tokens = splitRunsBy isSpaceTab line
      withTokens = foldl (pushToken acc.lineStart) withNewline tokens
    in
      { items: withTokens, lineStart: acc.lineStart + CU.length line + 1, li: acc.li + 1 }
  pushToken lineStart items run
    | run.isWs = items
    | run.text == "/" = if preserve then snoc items (SlashItem (lineStart + run.start)) else items
    | otherwise = snoc items (TokenItem run.text (lineStart + run.start))

type DecodeState = { bytes :: Array Int, spans :: Array Span, segs :: Array Segment }

flushBytes :: DecodeState -> DecodeState
flushBytes st =
  if length st.bytes > 0 then { bytes: [], spans: [], segs: snoc st.segs (BytesSeg st.bytes st.spans) }
  else st

pushWs :: DecodeState -> String -> Int -> DecodeState
pushWs st text start =
  let
    flushed = flushBytes st
  in
    flushed { segs = snoc flushed.segs (WsSeg text start (start + CU.length text)) }

-- | Decode source text in `format` into segments carrying input spans.
decodeInput :: CodeFormat -> Boolean -> String -> Either String (Array Segment)
decodeInput Letters preserve input
  | not preserve = Right [ textToByteSegment 0 input ]
  | otherwise = Right (map runToSeg (splitRunsBy isWsChar input))
      where
      runToSeg run
        | run.isWs = WsSeg run.text run.start (run.start + CU.length run.text)
        | otherwise = textToByteSegment run.start run.text
decodeInput format preserve input =
  map (\st -> (flushBytes st).segs)
    (foldM step { bytes: [], spans: [], segs: [] } (codedItems preserve input))
  where
  step st (NewlineItem start) = Right (pushWs st "\n" start)
  step st (SlashItem start) = Right (pushWs st " " start)
  step st (TokenItem token start) = case tokenToBytes format token of
    Left err -> Left err
    Right bs ->
      let
        span = { start, end: start + CU.length token }
      in
        Right (st { bytes = st.bytes <> bs, spans = st.spans <> map (const span) bs })

-- encoding ---------------------------------------------------------------

-- | Split a byte run into UTF-8 characters, merging each char's byte spans.
bytesToCharTokens :: Array Int -> Array Span -> Array OutToken
bytesToCharTokens bytes spans = go 0 []
  where
  total = length bytes
  go i acc
    | i >= total = acc
    | otherwise =
        let
          b = fromMaybe 0 (index bytes i)
          charLen = if b < 0x80 then 1 else if b >= 0xF0 then 4 else if b >= 0xE0 then 3 else if b >= 0xC0 then 2 else 1
          text = utf8DecodeImpl (slice i (i + charLen) bytes)
          first = fromMaybe { start: 0, end: 0 } (index spans i)
          lastSpan = fromMaybe first (index spans (min (i + charLen) (length spans) - 1))
        in
          go (i + charLen) (snoc acc { text, kind: "code", srcStart: first.start, srcEnd: lastSpan.end })

sepTokens :: Array OutToken -> Array OutToken
sepTokens tokens = case last tokens of
  Nothing -> tokens
  Just prev ->
    if endsWithWs prev.text then tokens
    else snoc tokens { text: " ", kind: "plain", srcStart: -1, srcEnd: -1 }

formatByte :: CodeFormat -> Int -> String
formatByte Binary b = padZeros 8 (Int.toStringAs Int.binary b)
formatByte Hex b = padZeros 2 (Int.toStringAs Int.hexadecimal b)
formatByte _ b = show b

-- | Encode segments into `format`, keeping per-token input spans.
encodeSegs :: CodeFormat -> Boolean -> Array Segment -> Array OutToken
encodeSegs format preserve segs = pruneStrandedSep (foldl seg [] segs)
  where
  seg tokens (WsSeg text start end)
    | not preserve = tokens
    | format == Letters = snoc tokens { text, kind: "plain", srcStart: start, srcEnd: end }
    | otherwise = foldl (wsChar start end) tokens (CU.toCharArray text)
  seg tokens (BytesSeg bytes spans)
    | format == Letters = tokens <> bytesToCharTokens bytes spans
    | otherwise = foldl (byteToken spans) tokens (mapWithIndex (\i b -> { i, b }) bytes)

  wsChar start end tokens ch
    | ch == '\n' = snoc tokens { text: "\n", kind: "plain", srcStart: start, srcEnd: end }
    | otherwise = snoc (sepTokens tokens) { text: "/", kind: "code", srcStart: start, srcEnd: end }

  byteToken spans tokens { i, b } =
    let
      span = fromMaybe { start: -1, end: -1 } (index spans i)
    in
      snoc (sepTokens tokens) { text: formatByte format b, kind: "code", srcStart: span.start, srcEnd: span.end }

  -- A separator stranded before a newline would render as trailing space.
  pruneStrandedSep tokens = catMaybes (mapWithIndex keep tokens)
    where
    keep i t =
      if t.text == " " && t.kind == "plain" && map _.text (index tokens (i + 1)) == Just "\n" then Nothing
      else Just t

-- entry point ------------------------------------------------------------

type TranscodeJs =
  { ok :: Boolean
  , error :: String
  , output :: String
  , bytes :: Array Int
  , tokens :: Array OutToken
  }

-- | JS-friendly entry point: plain-string formats in a flat record, so the
-- | TypeScript shim needs no knowledge of curried or ADT conventions.
transcodeJs :: { input :: String, from :: String, to :: String, preserveWhitespace :: Boolean } -> TranscodeJs
transcodeJs args =
  if args.input == "" then { ok: true, error: "", output: "", bytes: [], tokens: [] }
  else case decodeInput (parseFormat args.from) args.preserveWhitespace args.input of
    Left err -> { ok: false, error: err, output: "", bytes: [], tokens: [] }
    Right segs ->
      let
        tokens = encodeSegs (parseFormat args.to) args.preserveWhitespace segs
      in
        { ok: true
        , error: ""
        , output: joinWith "" (map _.text tokens)
        , bytes: concatMap segBytes segs
        , tokens
        }
