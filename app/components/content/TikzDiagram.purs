-- | ## TikzDiagram
-- |
-- | The setup composable behind `TikzDiagram.vue`, the client-side TikZ
-- | renderer. It lazily injects the tikzjax script and stylesheet once,
-- | hands the source to tikzjax through a `text/tikz` script, and waits for
-- | the `tikzjax-load-finished` event from inside its own figure (giving up
-- | after 30 s). Once the SVG is in, light fills are tagged so they stay
-- | visible in dark mode — strokes and text are forced to `currentColor` by
-- | the SFC's styles — and the fixed width tikzjax writes becomes a
-- | `max-width`, so the diagram shrinks with the column instead of
-- | overflowing it. The SFC keeps the prop macro and the template ref plus
-- | one call here; the DOM work lives behind the FFI edge.
module App.Components.TikzDiagram
  ( DomElement
  , SvgElement
  , TikzArgs
  , TikzBindings
  , isLightFill
  , luminance
  , setup
  , svgMaxWidth
  , tikzCaption
  ) where

import Prelude

import Data.Array ((!!))
import Data.Array.NonEmpty as NEA
import Data.Foldable (for_)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String (Pattern(..), split, trim)
import Data.String.Regex (Regex, match, replace, test)
import Data.String.Regex.Flags (ignoreCase, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , EffectFn4
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  , runEffectFn4
  )
import Vue (Computed, Ref, computed, onMounted, read, ref, write)

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

-- | An element of the rendered diagram: the `<svg>` itself or one of its
-- | shapes. @ts SVGElement
foreign import data SvgElement :: Type

foreign import attemptImpl :: EffectFn2 (Effect Unit) (EffectFn1 String Unit) Unit

foreign import ensureStylesheetImpl :: EffectFn1 String Unit

foreign import hasScriptImpl :: EffectFn1 String Boolean

foreign import loadScriptImpl :: EffectFn3 String (Effect Unit) (Effect Unit) Unit

foreign import mountSourceImpl :: EffectFn3 DomElement String String Unit

foreign import awaitRenderedImpl :: EffectFn4 DomElement Int (Effect Unit) (Effect Unit) Unit

foreign import svgOfImpl :: EffectFn1 DomElement (Nullable SvgElement)

foreign import widthAttrImpl :: EffectFn1 SvgElement (Nullable String)

foreign import sizeResponsiveImpl :: EffectFn2 SvgElement String Unit

foreign import shapesImpl :: EffectFn1 SvgElement (Array SvgElement)

foreign import computedFillImpl :: EffectFn1 SvgElement String

foreign import tagLightImpl :: EffectFn1 SvgElement Unit

foreign import parseFloatImpl :: String -> Number

cdn :: String
cdn = "https://cdn.jsdelivr.net/npm/@drgrice1/tikzjax@1.0.0-beta24/dist"

tikzjaxJs :: String
tikzjaxJs = cdn <> "/tikzjax.js"

tikzjaxCss :: String
tikzjaxCss = cdn <> "/fonts.css"

tikzLibraries :: String
tikzLibraries = "automata,positioning,arrows.meta,calc,cd"

renderTimeoutMs :: Int
renderTimeoutMs = 30000

lightThreshold :: Number
lightThreshold = 0.62

centeredWord :: Regex
centeredWord = unsafeRegex "\\bcentered\\b" noFlags

rgbColor :: Regex
rgbColor = unsafeRegex "rgba?\\(([^)]+)\\)" noFlags

hasUnit :: Regex
hasUnit = unsafeRegex "[a-z%]" ignoreCase

-- | The caption the code fence's meta string carries: the meta with its
-- | first `centered` layout flag taken out, or null when nothing is left.
tikzCaption :: Nullable String -> Nullable String
tikzCaption meta =
  case trim (replace centeredWord "" (fromMaybe "" (toMaybe meta))) of
    "" -> null
    caption -> notNull caption

-- | Relative luminance of 0–255 channels, from 0 (black) to 1 (white).
luminance :: Number -> Number -> Number -> Number
luminance r g b = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0

-- | Whether a computed `fill` is a light, visible `rgb()`/`rgba()` colour —
-- | one that would vanish against the dark theme's background. A fully
-- | transparent fill is not; a colour that does not parse is not.
isLightFill :: String -> Boolean
isLightFill fill = case channelsOf fill of
  Nothing -> false
  Just parts ->
    let
      alpha = fromMaybe 1.0 (parts !! 3)
    in
      case parts !! 0, parts !! 1, parts !! 2 of
        Just r, Just g, Just b -> alpha /= 0.0 && luminance r g b > lightThreshold
        _, _, _ -> false

channelsOf :: String -> Maybe (Array Number)
channelsOf fill = do
  groups <- match rgbColor fill
  inner <- join (NEA.index groups 1)
  pure (map parseFloatImpl (split (Pattern ",") inner))

-- | The `max-width` for an SVG whose `width` attribute was the given value:
-- | the value itself when it carries a unit, pixels when it is bare.
svgMaxWidth :: String -> String
svgMaxWidth width
  | test hasUnit width = width
  | otherwise = width <> "px"

type TikzArgs =
  { -- | Reads the `code` prop: the TikZ source to render.
    code :: Effect String
  -- | Reads the `meta` prop: the code fence's meta string, if any.
  , meta :: Effect (Nullable String)
  -- | Template ref to the element the diagram renders into.
  , target :: Ref (Nullable DomElement)
  }

type TikzBindings =
  { -- | Whether the diagram is still on its way.
    loading :: Ref Boolean
  -- | Why the diagram failed, or empty while it has not.
  , error :: Ref String
  -- | The figure caption, or null for none.
  , caption :: Computed (Nullable String)
  }

-- | Wires a TikZ figure: the caption drawn from the meta string, and on
-- | mount the render — assets, source hand-off, the wait for tikzjax, then
-- | the light-fill and responsive-size passes over the SVG it produced.
setup :: TikzArgs -> Effect TikzBindings
setup args = do
  loading <- ref true
  error <- ref ""
  caption <- computed (tikzCaption <$> args.meta)
  scriptLoaded <- Ref.new false

  let
    fail message = do
      write error ("diagram failed: " <> message)
      write loading false

    attempt action = runEffectFn2 attemptImpl action (mkEffectFn1 fail)

    ensureTikzjax next = do
      loaded <- Ref.read scriptLoaded
      if loaded then next
      else do
        runEffectFn1 ensureStylesheetImpl tikzjaxCss
        present <- runEffectFn1 hasScriptImpl tikzjaxJs
        let ready = Ref.write true scriptLoaded *> next
        if present then ready
        else runEffectFn3 loadScriptImpl tikzjaxJs (attempt ready) (fail "failed to load tikzjax")

    tagLightFills root = do
      svg <- toMaybe <$> runEffectFn1 svgOfImpl root
      for_ svg \element -> do
        shapes <- runEffectFn1 shapesImpl element
        for_ shapes \shape -> do
          fill <- runEffectFn1 computedFillImpl shape
          when (isLightFill fill) (runEffectFn1 tagLightImpl shape)

    makeResponsive root = do
      svg <- toMaybe <$> runEffectFn1 svgOfImpl root
      for_ svg \element -> do
        width <- toMaybe <$> runEffectFn1 widthAttrImpl element
        case width of
          Just value | value /= "" ->
            runEffectFn2 sizeResponsiveImpl element (svgMaxWidth value)
          _ -> pure unit

    finish root = do
      tagLightFills root
      makeResponsive root
      write loading false

    render = do
      write loading true
      write error ""
      target <- toMaybe <$> read args.target
      for_ target \root -> attempt $ ensureTikzjax do
        source <- args.code
        runEffectFn3 mountSourceImpl root tikzLibraries source
        runEffectFn4 awaitRenderedImpl root renderTimeoutMs (attempt (finish root))
          (fail "tikz timed out")

  onMounted render

  pure { loading, error, caption }
