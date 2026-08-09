-- | ## Katex
-- |
-- | TeX-to-HTML rendering. The KaTeX engine and macro map live behind typed
-- | FFI in `app/ffi/katex.ts`; errors never throw — the raw source comes
-- | back on failure.
module App.Utils.Katex
  ( renderTex
  , renderTexJs
  ) where

import Data.Function.Uncurried (Fn2, runFn2)

foreign import renderTexImpl :: Fn2 String Boolean String

-- | Renders a TeX string to HTML+MathML with the course macro map. Set
-- | `displayMode` for centered block math.
renderTex :: String -> Boolean -> String
renderTex = runFn2 renderTexImpl

renderTexJs :: Fn2 String Boolean String
renderTexJs = renderTexImpl
