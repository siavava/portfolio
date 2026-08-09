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

import Control.Monad.ST as ST
import Control.Monad.ST.Ref as STRef
import Data.Array (catMaybes, concat, concatMap, groupBy, index, length, mapWithIndex, slice, snoc)
import Data.Array.NonEmpty as NEA
import Data.Array.ST as STA
import Data.Either (Either(..))
import Data.Foldable (all, foldl)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Monoid (power)
import Data.Nullable (Nullable)
import Data.String (Pattern(..), joinWith, split, toLower)
import Data.String.CodeUnits as CU
import Data.Traversable (mapAccumL, traverse)

-- | UTF-8 bytes of a string (`TextEncoder`).
foreign import utf8EncodeImpl :: String -> Array Int

-- | String from UTF-8 bytes (`TextDecoder`, non-fatal — invalid
-- | sequences become U+FFFD).
foreign import utf8DecodeImpl :: Array Int -> String

-- | The string split into per-code-point strings (`Array.from(str)`).
foreign import codePointStringsImpl :: String -> Array String

-- | base64url-encode arbitrary text for share links.
foreign import encodeShareText :: String -> String

-- | Decode a share-link payload; null if malformed.
foreign import decodeShareText :: String -> Nullable String

-- | The four byte representations `/code` transcodes between.
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
type OutToken =
  { -- | The token's rendered text.
    text :: String
  , -- | `"code"` for byte/character tokens, `"plain"` for whitespace and
    -- | synthesized separators.
    kind :: String
  , -- | Start of the source span, in code units into the input text; -1
    -- | on synthesized separators.
    srcStart :: Int
  , -- | End (exclusive) of the source span; -1 on synthesized separators.
    srcEnd :: Int
  }

data Segment
  = BytesSeg (Array Int) (Array Span)
  | WsSeg String Int Int

segBytes :: Segment -> Array Int
segBytes (BytesSeg bytes _) = bytes
segBytes _ = []

-- character classes ------------------------------------------------------

-- Matches the JS \s class the TS original split whitespace with.
isWsChar :: Char -> Boolean
isWsChar c =
  c == ' '
    || c == '\t'
    || c == '\n'
    || c == '\r'
    || c == '\x0B'
    || c == '\x0C'
    || c == '\x00A0'
    || c == '\x1680'
    || (c >= '\x2000' && c <= '\x200A')
    || c == '\x2028'
    || c == '\x2029'
    || c == '\x202F'
    || c == '\x205F'
    || c == '\x3000'
    || c == '\xFEFF'

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
              { runs: snoc st.runs cur
              , current: Just { isWs: ws, text: chStr, start: st.pos }
              , pos: st.pos + 1
              }
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
textToByteSegment offset text =
  BytesSeg (concatMap _.encoded chunks) (concatMap spanBytes chunks)
  where
  chunks = (mapAccumL step 0 (codePointStringsImpl text)).value
  step pos ch =
    let
      chLen = CU.length ch
    in
      { accum: pos + chLen
      , value:
          { encoded: utf8EncodeImpl ch
          , span: { start: offset + pos, end: offset + pos + chLen }
          }
      }
  spanBytes chunk = map (const chunk.span) chunk.encoded

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

-- | A parsed scanner item: preserved whitespace, or one token's bytes all
-- | sharing the token's input span.
data Chunk = WsChunk String Int | ByteChunk (Array Int) Span

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
  map chunksToSegs (traverse parseItem (codedItems preserve input))
  where
  parseItem (NewlineItem start) = Right (WsChunk "\n" start)
  parseItem (SlashItem start) = Right (WsChunk " " start)
  parseItem (TokenItem token start) =
    map (\bs -> ByteChunk bs { start, end: start + CU.length token }) (tokenToBytes format token)

  chunksToSegs chunks = concatMap groupSegs (groupBy bothBytes chunks)

  bothBytes a b = isByteChunk a && isByteChunk b

  isByteChunk (ByteChunk _ _) = true
  isByteChunk _ = false

  groupSegs grp = case NEA.head grp of
    WsChunk text start -> [ WsSeg text start (start + CU.length text) ]
    ByteChunk _ _ ->
      let
        parts = NEA.toArray grp
      in
        [ BytesSeg (concatMap chunkBytes parts) (concatMap chunkSpans parts) ]

  chunkBytes (ByteChunk bs _) = bs
  chunkBytes _ = []

  chunkSpans (ByteChunk bs span) = map (const span) bs
  chunkSpans _ = []

-- encoding ---------------------------------------------------------------

-- | Split a byte run into UTF-8 characters, merging each char's byte spans.
bytesToCharTokens :: Array Int -> Array Span -> Array OutToken
bytesToCharTokens bytes spans = STA.run do
  out <- STA.new
  cursor <- STRef.new 0
  ST.while (map (_ < total) (STRef.read cursor)) do
    i <- STRef.read cursor
    let
      b = fromMaybe 0 (index bytes i)
      charLen =
        if b < 0x80 then 1
        else if b >= 0xF0 then 4
        else if b >= 0xE0 then 3
        else if b >= 0xC0 then 2
        else 1
      text = utf8DecodeImpl (slice i (i + charLen) bytes)
      first = fromMaybe { start: 0, end: 0 } (index spans i)
      lastSpan = fromMaybe first (index spans (min (i + charLen) (length spans) - 1))
    _ <- STA.push { text, kind: "code", srcStart: first.start, srcEnd: lastSpan.end } out
    STRef.write (i + charLen) cursor
  pure out
  where
  total = length bytes

formatByte :: CodeFormat -> Int -> String
formatByte Binary b = padZeros 8 (Int.toStringAs Int.binary b)
formatByte Hex b = padZeros 2 (Int.toStringAs Int.hexadecimal b)
formatByte _ b = show b

-- | Encode segments into `format`, keeping per-token input spans.
encodeSegs :: CodeFormat -> Boolean -> Array Segment -> Array OutToken
encodeSegs Letters preserve segs = pruneStrandedSep (concatMap seg segs)
  where
  seg (WsSeg text start end)
    | preserve = [ { text, kind: "plain", srcStart: start, srcEnd: end } ]
    | otherwise = []
  seg (BytesSeg bytes spans) = bytesToCharTokens bytes spans
encodeSegs format preserve segs = pruneStrandedSep (concat (mapWithIndex withSep emissions))
  where
  emissions = concatMap seg segs

  seg (WsSeg text start end)
    | preserve = map (wsToken start end) (CU.toCharArray text)
    | otherwise = []
  seg (BytesSeg bytes spans) = mapWithIndex (byteToken spans) bytes

  wsToken start end ch
    | ch == '\n' = { text: "\n", kind: "plain", srcStart: start, srcEnd: end }
    | otherwise = { text: "/", kind: "code", srcStart: start, srcEnd: end }

  byteToken spans i b =
    let
      span = fromMaybe { start: -1, end: -1 } (index spans i)
    in
      { text: formatByte format b, kind: "code", srcStart: span.start, srcEnd: span.end }

  -- The token before emission `i` is always emission `i - 1`, so the
  -- separator check reads it instead of the accumulated output.
  withSep i tok = case index emissions (i - 1) of
    Just prev
      | tok.text /= "\n" && not (endsWithWs prev.text) ->
          [ { text: " ", kind: "plain", srcStart: -1, srcEnd: -1 }, tok ]
    _ -> [ tok ]

-- | A separator stranded before a newline would render as trailing space.
pruneStrandedSep :: Array OutToken -> Array OutToken
pruneStrandedSep tokens = catMaybes (mapWithIndex keep tokens)
  where
  keep i t =
    if t.text == " " && t.kind == "plain" && map _.text (index tokens (i + 1)) == Just "\n" then
      Nothing
    else Just t

-- entry point ------------------------------------------------------------

-- | What `transcodeJs` hands the TypeScript shim.
type TranscodeJs =
  { -- | False when the input failed to parse in the source format.
    ok :: Boolean
  , -- | The parse error when `ok` is false; empty otherwise.
    error :: String
  , -- | The whole output text — the concatenated token texts.
    output :: String
  , -- | The decoded byte values, independent of the output format.
    bytes :: Array Int
  , -- | The output tokens with source spans, for cross-pane highlighting.
    tokens :: Array OutToken
  }

-- | JS-friendly entry point: plain-string formats in a flat record, so the
-- | TypeScript shim needs no knowledge of curried or ADT conventions.
transcodeJs
  :: { input :: String, from :: String, to :: String, preserveWhitespace :: Boolean } -> TranscodeJs
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
