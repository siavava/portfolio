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
  , useCodePage
  ) where

import Prelude

import App.Utils.Coder (decodeShareText, encodeShareText, transcodeJs)
import Data.Array (catMaybes, elem, length, mapWithIndex, slice) as Array
import Data.Char (fromCharCode)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Monoid (power)
import Data.Nullable (Nullable, toMaybe)
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
foreign import data IntSet :: Type
foreign import data RouteQuery :: Type
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

foreign import shareUrlImpl :: EffectFn4 String String Boolean String String
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit
foreign import bitstripImpl :: String -> String

-- | One rendered piece of output, structurally identical to
-- | `App.Utils.Coder.OutToken` so the generated declarations stay precise.
type OutToken = { text :: String, kind :: String, srcStart :: Int, srcEnd :: Int }

type Sample = { label :: String, text :: String, from :: String, to :: String }

type CodeArgs =
  { inputEl :: Ref (Nullable TextAreaEl)
  , outEl :: Ref (Nullable DomElement)
  , query :: RouteQuery
  }

type CodeBindings =
  { input :: Ref String
  , from :: Ref String
  , to :: Ref String
  , preserve :: Ref Boolean
  , output :: Computed String
  , error :: Computed String
  , bytes :: Computed (Array Int)
  , tokens :: Computed (Array OutToken)
  , hotTokens :: Computed IntSet
  , byteCount :: Computed Int
  , shownBytes :: Computed (Array Int)
  , outputUnits :: Computed String
  , inputPlaceholder :: Computed String
  , bitstrip :: Computed String
  , swapTurns :: Ref Int
  , copied :: Ref Boolean
  , shared :: Ref Boolean
  , tipVisible :: Ref Boolean
  , samples :: Array Sample
  , byteCap :: Int
  , trackCursor :: Effect Unit
  , swap :: Effect Unit
  , copyOutput :: Effect Unit
  , share :: Effect Unit
  , startTipTimer :: Effect Unit
  , clearTipTimer :: Effect Unit
  , loadSample :: EffectFn1 Sample Unit
  , byteTitle :: Int -> String
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

unitName :: String -> String
unitName "letters" = "chars"
unitName "binary" = "bits"
unitName "hex" = "nibbles"
unitName _ = "bytes"

placeholder :: String -> String
placeholder "binary" = "01101000 01101001 …"
placeholder "decimal" = "104 101 108 …"
placeholder "hex" = "68 65 6c 6c 6f …"
placeholder _ = "type anything…"

padZeros :: Int -> String -> String
padZeros width s = power "0" (max 0 (width - CU.length s)) <> s

byteTitle :: Int -> String
byteTitle b =
  let
    ch = case fromCharCode b of
      Just c | b >= 32 && b < 127 -> CU.singleton c
      _ -> "·"
  in
    ch <> "  dec " <> show b <> "  bin " <> padZeros 8 (Int.toStringAs Int.binary b)

hotIndex :: Int -> Int -> OutToken -> Maybe Int
hotIndex pos i t =
  if t.kind == "code" && t.srcStart >= 0 && pos >= t.srcStart && pos <= t.srcEnd then Just i
  else Nothing

useCodePage :: EffectFn1 CodeArgs CodeBindings
useCodePage = mkEffectFn1 setup

setup :: CodeArgs -> Effect CodeBindings
setup args = do
  let
    param key = toMaybe (runFn2 queryParamImpl args.query key)

    pickFormat fallback key = case param key of
      Just v | Array.elem v formatIds -> v
      _ -> fallback

    sharedText = param "q" >>= (decodeShareText >>> toMaybe)

  input <- ref (fromMaybe "" sharedText)
  from <- ref (pickFormat "letters" "from")
  to <- ref (pickFormat "binary" "to")
  preserve <- ref case param "ws" of
    Nothing -> true
    Just ws -> ws /= "0"
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
    let hot = if pos < 0 then [] else Array.catMaybes (Array.mapWithIndex (hotIndex pos) toks)
    pure (mkIntSetImpl hot)

  byteCount <- computed (Array.length <$> read bytes)
  shownBytes <- computed (Array.slice 0 byteCap <$> read bytes)

  outputUnits <- computed do
    n <- read byteCount
    t <- read to
    let scaled = if t == "binary" then n * 8 else if t == "hex" then n * 2 else n
    if t == "letters" then do
      o <- read output
      pure (show (CU.length o) <> " chars")
    else
      pure (show scaled <> " " <> unitName t <> " · " <> show n <> " bytes")

  inputPlaceholder <- computed (placeholder <$> read from)

  -- Deterministic: Math.random here would mismatch on hydration.
  bitstrip <- computed do
    i <- read input
    pure (bitstripImpl (if i == "" then "code" else i))

  clipOut <- runEffectFn1 useClipboardImpl 1200
  clipLink <- runEffectFn1 useClipboardImpl 1600

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
    , tokens
    , hotTokens
    , byteCount
    , shownBytes
    , outputUnits
    , inputPlaceholder
    , bitstrip
    , swapTurns
    , copied: clipOut.copied
    , shared: clipLink.copied
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
    }
