-- | ## CodePage
-- |
-- | The setup composable behind `pages/code.vue`: the `/code` transcoder's
-- | state, share-link handling, cursor-to-output highlighting, and textarea
-- | plumbing. Conversion itself is `App.Utils.Coder.transcodeJs`; the SFC
-- | keeps only the template refs and glue composables. The module lives
-- | under `app/components/` because a generated FFI stub in `app/pages/`
-- | would be scanned as a route.
module App.Components.CodePage
  ( CodeArgs
  , CodeBindings
  , DomElement
  , IntSet
  , OutToken
  , RouteQuery
  , Sample
  , TextAreaEl
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
  , setup
  , shareLinkLabelFor
  , shareTitleFor
  , swapTransform
  , unitName
  , unitsSummary
  ) where

import Prelude

import App.Utils.Coder (decodeShareText, encodeShareText, transcodeJs)
import Data.Array (catMaybes, elem, length, mapWithIndex, slice) as Array
import Data.Char (fromCharCode)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe, isJust, maybe)
import Data.Monoid (power)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String (trim)
import Data.String.CodeUnits as CU
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Effect.Uncurried (EffectFn1, EffectFn4, mkEffectFn1, runEffectFn1, runEffectFn4)
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , onUnmounted
  , read
  , ref
  , watchGetter
  , watchRef
  , write
  )

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | A JS `Set` of `Int` indices — cheap `has` lookups from the template.
foreign import data IntSet :: Type

-- | The current route's query object (`useRoute().query`), read key by key
-- | through `queryParamImpl`.
foreign import data RouteQuery :: Type

-- | A DOM `HTMLTextAreaElement` — the input panel's element.
foreign import data TextAreaEl :: Type

foreign import queryParamImpl :: Fn2 RouteQuery String (Nullable String)

foreign import selectionStartImpl :: EffectFn1 (Nullable TextAreaEl) Int

foreign import autoGrowImpl :: EffectFn1 (Nullable TextAreaEl) Unit

foreign import onWindowResizeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

foreign import mkIntSetImpl :: Array Int -> IntSet

foreign import setSizeImpl :: IntSet -> Int

foreign import scrollHotIntoViewImpl :: EffectFn1 (Nullable DomElement) Unit

foreign import useClipboardImpl
  :: EffectFn1 Int { copy :: EffectFn1 String Unit, copied :: Ref Boolean }

-- | Reads `location.origin`, so client-only.
foreign import shareUrlImpl :: EffectFn4 String String Boolean String String

foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

foreign import bitstripImpl :: String -> String

-- | One rendered piece of output, structurally identical to
-- | `App.Utils.Coder.OutToken` so the generated declarations stay precise.
type OutToken = { text :: String, kind :: String, srcStart :: Int, srcEnd :: Int }

type Sample = { label :: String, text :: String, from :: String, to :: String }

type CodeArgs =
  { -- | Template ref to the source textarea.
    inputEl :: Ref (Nullable TextAreaEl)
  -- | Template ref to the rendered output panel.
  , outEl :: Ref (Nullable DomElement)
  -- | The route's query — seeds input/formats from a share link.
  , query :: RouteQuery
  }

type CodeBindings =
  { -- | Source text, v-modeled by the input textarea.
    input :: Ref String
  -- | Source format id: letters, binary, decimal, or hex.
  , from :: Ref String
  -- | Target format id.
  , to :: Ref String
  -- | Whitespace-preservation toggle.
  , preserve :: Ref Boolean
  -- | Transcoded text; empty while the input fails to parse.
  , output :: Computed String
  -- | Conversion error message; empty on success.
  , error :: Computed String
  -- | Decoded byte values feeding the ribbon and counts.
  , bytes :: Computed (Array Int)
  -- | Length of the input in UTF-16 code units, like JS `.length`.
  , charCount :: Computed Int
  -- | True once anything is typed — fades the "try" chips away.
  , inputUsed :: Computed Boolean
  -- | Chip tab index: out of the tab order (-1) once the input is used.
  , chipTabindex :: Computed Int
  -- | Output split into code/plain runs carrying source spans.
  , tokens :: Computed (Array OutToken)
  -- | Indices of tokens covering the input caret — the highlight set.
  , hotTokens :: Computed IntSet
  -- | Number of decoded bytes.
  , byteCount :: Computed Int
  -- | First `byteCap` bytes, so the ribbon stays bounded.
  , shownBytes :: Computed (Array Int)
  -- | "+N more" past the ribbon's cap; null when every byte is shown.
  , moreBytes :: Computed (Nullable String)
  -- | Output-panel footer summary, e.g. "16 bits · 2 bytes".
  , outputUnits :: Computed String
  -- | Input placeholder matching the source format.
  , inputPlaceholder :: Computed String
  -- | Decorative bit string across the top, seeded by the input.
  , bitstrip :: Computed String
  -- | Swap click count — drives the button's 180° rotations.
  , swapTurns :: Ref Int
  -- | The swap button's inline style: half a turn per swap.
  , swapStyle :: Computed { transform :: String }
  -- | True briefly after copying the output.
  , copied :: Ref Boolean
  -- | True briefly after copying a share link.
  , shared :: Ref Boolean
  -- | Whether there is anything but whitespace to share.
  , canShare :: Computed Boolean
  -- | The share button's hover title.
  , shareTitle :: Computed String
  -- | The share button's label, confirming a copied link.
  , shareLabel :: Computed String
  -- | The copy button's label, confirming a copy.
  , copyLabel :: Computed String
  -- | Copy is off with no output or while the input fails to parse.
  , copyDisabled :: Computed Boolean
  -- | Output-panel placeholder: a dash on error, else "output".
  , outPlaceholder :: Computed String
  -- | Whitespace-toggle tooltip shown (after a hover delay).
  , tipVisible :: Ref Boolean
  -- | Canned "try" conversions.
  , samples :: Array Sample
  -- | Max bytes rendered in the ribbon.
  , byteCap :: Int
  -- | Records the textarea caret to drive hot-token highlighting.
  , trackCursor :: Effect Unit
  -- | Swaps from/to, feeding the output back in when it was valid.
  , swap :: Effect Unit
  -- | Copies the output text.
  , copyOutput :: Effect Unit
  -- | Copies a share URL encoding the current conversion.
  , share :: Effect Unit
  -- | Arms the 2 s timer that shows the whitespace tip.
  , startTipTimer :: Effect Unit
  -- | Cancels the timer and hides the whitespace tip.
  , clearTipTimer :: Effect Unit
  -- | Fills input/from/to from a sample.
  , loadSample :: EffectFn1 Sample Unit
  -- | Hover title for a byte chip: glyph, decimal, binary.
  , byteTitle :: Int -> String
  -- | A byte chip's text: two lowercase hex digits.
  , byteHex :: Int -> String
  }

byteCap :: Int
byteCap = 160

formatIds :: Array String
formatIds = [ "letters", "binary", "decimal", "hex" ]

samples :: Array Sample
samples =
  [ { label: "hello, world", text: "hello, world", from: "letters", to: "binary" }
  , { label: "01101000 01101001", text: "01101000 01101001", from: "binary", to: "letters" }
  , { label: "deadbeef", text: "de ad be ef", from: "hex", to: "decimal" }
  ]

-- | The unit the output footer counts in, per target format id.
unitName :: String -> String
unitName "letters" = "chars"
unitName "binary" = "bits"
unitName "hex" = "nibbles"
unitName _ = "bytes"

-- | The input placeholder per source format id; letters (and anything
-- | unknown) get the free-text prompt.
formatPlaceholder :: String -> String
formatPlaceholder "binary" = "01101000 01101001 …"
formatPlaceholder "decimal" = "104 101 108 …"
formatPlaceholder "hex" = "68 65 6c 6c 6f …"
formatPlaceholder _ = "type anything…"

padZeros :: Int -> String -> String
padZeros width s = power "0" (max 0 (width - CU.length s)) <> s

-- | Hover title for a byte chip: the glyph (a middle dot outside
-- | printable ASCII), the decimal value, and eight binary digits.
byteTitle :: Int -> String
byteTitle b =
  let
    ch = case fromCharCode b of
      Just c | b >= 32 && b < 127 -> CU.singleton c
      _ -> "·"
  in
    ch <> "  dec " <> show b <> "  bin " <> padZeros 8 (Int.toStringAs Int.binary b)

-- | A byte chip's text: the value in lowercase hex, padded to two digits
-- | (JS `b.toString(16).padStart(2, "0")`).
byteHex :: Int -> String
byteHex b = padZeros 2 (Int.toStringAs Int.hexadecimal b)

-- | The ribbon's overflow label, "+N more", for a byte count past the cap
-- | (first argument); null when every byte fits.
moreBytesLabel :: Int -> Int -> Nullable String
moreBytesLabel cap n
  | n > cap = notNull ("+" <> show (n - cap) <> " more")
  | otherwise = null

-- | The share button's title: an invitation once the input holds more
-- | than whitespace (JS `trim`), else why it is disabled.
shareTitleFor :: String -> String
shareTitleFor i
  | trim i /= "" = "copy a link to this exact conversion"
  | otherwise = "nothing to share yet"

-- | The swap button's CSS transform after the given number of swaps.
swapTransform :: Int -> String
swapTransform turns = "rotate(" <> show (turns * 180) <> "deg)"

-- | Copy is disabled for (output, error) when the output is empty or an
-- | error is showing — JS `!output || !!error`.
copyDisabledFor :: String -> String -> Boolean
copyDisabledFor output error = output == "" || error /= ""

-- | A share link's format param when it names a known format, else the
-- | fallback — a hand-edited URL cannot select a missing format.
seedFormat :: String -> Nullable String -> String
seedFormat fallback param = case toMaybe param of
  Just v | Array.elem v formatIds -> v
  _ -> fallback

-- | A share link's `ws` param: whitespace is preserved unless it is "0".
seedPreserve :: Nullable String -> Boolean
seedPreserve ws = maybe true (_ /= "0") (toMaybe ws)

-- | The token's index when it is a code token whose source span covers
-- | the caret (both ends inclusive); plain runs never light up (null).
hotIndex :: Int -> Int -> OutToken -> Nullable Int
hotIndex pos i t =
  if t.kind == "code" && t.srcStart >= 0 && pos >= t.srcStart && pos <= t.srcEnd then notNull i
  else null

-- | The indices of the tokens that light for a caret at `pos`; none while
-- | no caret has been recorded (a negative position).
hotIndices :: Int -> Array OutToken -> Array Int
hotIndices pos toks
  | pos < 0 = []
  | otherwise = Array.catMaybes (Array.mapWithIndex (\i -> toMaybe <<< hotIndex pos i) toks)

-- | The output footer's summary for a non-letters target: the count in its
-- | own unit — eight bits or two nibbles a byte — and the byte count.
unitsSummary :: String -> Int -> String
unitsSummary to n =
  let
    scaled = if to == "binary" then n * 8 else if to == "hex" then n * 2 else n
  in
    show scaled <> " " <> unitName to <> " · " <> show n <> " bytes"

-- | The "try" chips' tab index: out of the tab order once the input is used.
chipTabindexFor :: Boolean -> Int
chipTabindexFor used = if used then (-1) else 0

-- | The share button's label, confirming a copied link.
shareLinkLabelFor :: Boolean -> String
shareLinkLabelFor copied = if copied then "link copied" else "share ⇗"

-- | The copy button's label, confirming a copy.
copyLabelFor :: Boolean -> String
copyLabelFor copied = if copied then "copied" else "copy"

-- | The output panel's placeholder: a dash while an error shows.
outPlaceholderFor :: String -> String
outPlaceholderFor e = if e == "" then "output" else "—"

-- | The decorative bit strip for the input, seeded by "code" while it is
-- | empty.
bitstripFor :: String -> String
bitstripFor i = bitstripImpl (if i == "" then "code" else i)

-- | Wires the `/code` transcoder: seeds state from share-link query
-- | params, derives the conversion computeds and cursor-to-output
-- | highlight set, and manages clipboard, tip timer, and textarea
-- | auto-grow. Returns every ref and action `pages/code.vue` binds.
setup :: CodeArgs -> Effect CodeBindings
setup args = do
  let
    rawParam key = runFn2 queryParamImpl args.query key

    param key = toMaybe (rawParam key)

    sharedText = param "q" >>= (decodeShareText >>> toMaybe)

  input <- ref (fromMaybe "" sharedText)
  from <- ref (seedFormat "letters" (rawParam "from"))
  to <- ref (seedFormat "binary" (rawParam "to"))
  preserve <- ref (seedPreserve (rawParam "ws"))
  cursorPos <- ref (-1)
  swapTurns <- ref 0
  tipVisible <- ref false
  tipTimer <- Ref.new (Nothing :: Maybe TimeoutId)
  stopResize <- Ref.new (pure unit :: Effect Unit)

  result <- computed do
    i <- read input
    f <- read from
    t <- read to
    p <- read preserve
    pure (transcodeJs { input: i, from: f, to: t, preserveWhitespace: p })

  output <- computed do
    r <- read result
    pure (if r.ok then r.output else "")

  error <- computed do
    r <- read result
    pure (if r.ok then "" else r.error)

  bytes <- computed do
    r <- read result
    pure (if r.ok then r.bytes else [])

  tokens <- computed do
    r <- read result
    pure (if r.ok then r.tokens else [])

  hotTokens <- computed do
    pos <- read cursorPos
    toks <- read tokens
    pure (mkIntSetImpl (hotIndices pos toks))

  byteCount <- computed (Array.length <$> read bytes)
  shownBytes <- computed (Array.slice 0 byteCap <$> read bytes)
  moreBytes <- computed (moreBytesLabel byteCap <$> read byteCount)

  charCount <- computed (CU.length <$> read input)
  inputUsed <- computed ((_ > 0) <$> read charCount)
  chipTabindex <- computed (chipTabindexFor <$> read inputUsed)

  outputUnits <- computed do
    n <- read byteCount
    t <- read to
    if t == "letters" then do
      o <- read output
      pure (show (CU.length o) <> " chars")
    else
      pure (unitsSummary t n)

  inputPlaceholder <- computed (formatPlaceholder <$> read from)

  -- Deterministic: Math.random here would mismatch on hydration.
  bitstrip <- computed (bitstripFor <$> read input)

  swapStyle <- computed do
    turns <- read swapTurns
    pure { transform: swapTransform turns }

  clipOut <- runEffectFn1 useClipboardImpl 1200
  clipLink <- runEffectFn1 useClipboardImpl 1600

  canShare <- computed do
    i <- read input
    pure (trim i /= "")
  shareTitle <- computed (shareTitleFor <$> read input)
  shareLabel <- computed (shareLinkLabelFor <$> read clipLink.copied)
  copyLabel <- computed (copyLabelFor <$> read clipOut.copied)
  copyDisabled <- computed (copyDisabledFor <$> read output <*> read error)
  outPlaceholder <- computed (outPlaceholderFor <$> read error)

  let
    autoGrow = read args.inputEl >>= runEffectFn1 autoGrowImpl

    trackCursor = read args.inputEl >>= runEffectFn1 selectionStartImpl >>= write cursorPos

    swap = do
      prevOut <- read output
      err <- read error
      f <- read from
      t <- read to
      write from t
      write to f
      when (err == "" && prevOut /= "") (write input prevOut)
      turns <- read swapTurns
      write swapTurns (turns + 1)

    copyOutput = do
      o <- read output
      when (o /= "") (runEffectFn1 clipOut.copy o)

    startTipTimer = do
      pending <- setTimeout 2000 (write tipVisible true)
      Ref.write (Just pending) tipTimer

    clearTipTimer = do
      Ref.read tipTimer >>= case _ of
        Just pending -> clearTimeout pending *> Ref.write Nothing tipTimer
        Nothing -> pure unit
      write tipVisible false

    share = do
      i <- read input
      when (trim i /= "") do
        f <- read from
        t <- read to
        p <- read preserve
        url <- runEffectFn4 shareUrlImpl f t (not p) (encodeShareText i)
        runEffectFn1 clipLink.copy url

    loadSample s = do
      write input s.text
      write from s.from
      write to s.to

  _ <- watchRef input \_ -> runEffectFn1 nextTickImpl autoGrow

  _ <- watchGetter (read hotTokens) \hot _ -> do
    out <- read args.outEl
    when (setSizeImpl hot > 0 && isJust (toMaybe out)) do
      runEffectFn1 nextTickImpl (read args.outEl >>= runEffectFn1 scrollHotIntoViewImpl)

  onMounted do
    autoGrow
    stop <- runEffectFn1 onWindowResizeImpl autoGrow
    Ref.write stop stopResize
  onUnmounted (join (Ref.read stopResize))

  pure
    { input
    , from
    , to
    , preserve
    , output
    , error
    , bytes
    , charCount
    , inputUsed
    , chipTabindex
    , tokens
    , hotTokens
    , byteCount
    , shownBytes
    , moreBytes
    , outputUnits
    , inputPlaceholder
    , bitstrip
    , swapTurns
    , swapStyle
    , copied: clipOut.copied
    , shared: clipLink.copied
    , canShare
    , shareTitle
    , shareLabel
    , copyLabel
    , copyDisabled
    , outPlaceholder
    , tipVisible
    , samples
    , byteCap
    , trackCursor
    , swap
    , copyOutput
    , share
    , startTipTimer
    , clearTipTimer
    , loadSample: mkEffectFn1 loadSample
    , byteTitle
    , byteHex
    }
