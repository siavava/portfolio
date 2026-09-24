-- | Cases for the code-fence alias pass of the content pipeline, recorded
-- | from the TypeScript `transformers/fences.ts` before it was deleted:
-- | the whole alias table, fence lengths and indentation, info strings,
-- | pass-through languages, and the lines the pattern must not touch.
module Test.Transformers.Fences (suite) where

import Prelude

import App.Transformers.Fences (aliasOf, normalize)
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Test.Harness (Tally, expect)

type Alias = { lang :: String, canonical :: String }

aliases :: Array Alias
aliases =
  [ { lang: "py", canonical: "python" }
  , { lang: "py3", canonical: "python" }
  , { lang: "js", canonical: "javascript" }
  , { lang: "cjs", canonical: "javascript" }
  , { lang: "mjs", canonical: "javascript" }
  , { lang: "node", canonical: "javascript" }
  , { lang: "ts", canonical: "typescript" }
  , { lang: "rs", canonical: "rust" }
  , { lang: "rb", canonical: "ruby" }
  , { lang: "hs", canonical: "haskell" }
  , { lang: "md", canonical: "markdown" }
  , { lang: "mkd", canonical: "markdown" }
  , { lang: "sh", canonical: "shell" }
  , { lang: "bash", canonical: "shell" }
  , { lang: "zsh", canonical: "shell" }
  , { lang: "console", canonical: "shell" }
  , { lang: "shellscript", canonical: "shell" }
  , { lang: "c++", canonical: "cpp" }
  , { lang: "cc", canonical: "cpp" }
  , { lang: "cxx", canonical: "cpp" }
  , { lang: "hpp", canonical: "cpp" }
  , { lang: "yml", canonical: "yaml" }
  , { lang: "gql", canonical: "graphql" }
  , { lang: "fs", canonical: "fsharp" }
  , { lang: "f#", canonical: "fsharp" }
  , { lang: "golang", canonical: "go" }
  , { lang: "tex", canonical: "latex" }
  , { lang: "htm", canonical: "html" }
  , { lang: "jl", canonical: "julia" }
  ]

unaliased :: Array String
unaliased = [ "python", "algorithm", "tikz", "pyx", "PY", "constructor", "" ]

type Case = { label :: String, input :: String, out :: String }

cases :: Array Case
cases =
  [ { label: "four-backtick fence"
    , input: "````py\nx\n````"
    , out: "````python\nx\n````"
    }
  , { label: "five-backtick fence with a symbol alias"
    , input: "`````c++\nint x;\n`````"
    , out: "`````cpp\nint x;\n`````"
    }
  , { label: "space-indented fence keeps its indentation"
    , input: "  ```js\nlet a\n  ```"
    , out: "  ```javascript\nlet a\n  ```"
    }
  , { label: "three-space-indented fence"
    , input: "   ```md\n# h\n   ```"
    , out: "   ```markdown\n# h\n   ```"
    }
  , { label: "tab-indented fence keeps its indentation"
    , input: "\t```ts\nlet a\n\t```"
    , out: "\t```typescript\nlet a\n\t```"
    }
  , { label: "info string after a space is kept"
    , input: "```py title=x {1,3}\nx\n```"
    , out: "```python title=x {1,3}\nx\n```"
    }
  , { label: "highlight meta glued to the language is kept"
    , input: "```py{1,3}\nx\n```"
    , out: "```python{1,3}\nx\n```"
    }
  , { label: "the language ends at the first character outside the class"
    , input: "```js.x\nx\n```"
    , out: "```javascript.x\nx\n```"
    }
  , { label: "a hyphen extends the language past the alias"
    , input: "```py-x\nx\n```"
    , out: "```py-x\nx\n```"
    }
  , { label: "algorithm passes through"
    , input: "```algorithm\nstep\n```"
    , out: "```algorithm\nstep\n```"
    }
  , { label: "tikz passes through"
    , input: "```tikz\n\\draw;\n```"
    , out: "```tikz\n\\draw;\n```"
    }
  , { label: "canonical python passes through"
    , input: "```python\nx\n```"
    , out: "```python\nx\n```"
    }
  , { label: "pyx is not py"
    , input: "```pyx\nx\n```"
    , out: "```pyx\nx\n```"
    }
  , { label: "py3 becomes python"
    , input: "```py3\nx\n```"
    , out: "```python\nx\n```"
    }
  , { label: "uppercase PY is untouched"
    , input: "```PY\nx\n```"
    , out: "```PY\nx\n```"
    }
  , { label: "camel-case language is untouched"
    , input: "```hasOwnProperty\nx\n```"
    , out: "```hasOwnProperty\nx\n```"
    }
  , { label: "tilde fence is untouched"
    , input: "~~~py\nx\n~~~"
    , out: "~~~py\nx\n~~~"
    }
  , { label: "backticks after text on the line are untouched"
    , input: "text ```py inline\n```"
    , out: "text ```py inline\n```"
    }
  , { label: "two backticks are not a fence"
    , input: "``py\nx\n``"
    , out: "``py\nx\n``"
    }
  , { label: "bare fence is untouched"
    , input: "```\nplain\n```"
    , out: "```\nplain\n```"
    }
  , { label: "several fences in one body"
    , input: "intro\n\n```py\na\n```\n\nmid\n\n```rs\nb\n```\n\n```f#\nc\n```\n"
    , out: "intro\n\n```python\na\n```\n\nmid\n\n```rust\nb\n```\n\n```fsharp\nc\n```\n"
    }
  , { label: "CRLF line endings"
    , input: "```py\r\nx\r\n```\r\n```sh\r\nls\r\n```\r\n"
    , out: "```python\r\nx\r\n```\r\n```shell\r\nls\r\n```\r\n"
    }
  , { label: "constructor keeps the original's inherited-property lookup (node)"
    , input: "```constructor\nx\n```"
    , out: "```function Object() { [native code] }\nx\n```"
    }
  , { label: "empty body"
    , input: ""
    , out: ""
    }
  ]

suite :: Tally -> Effect Unit
suite t = do
  for_ aliases \a -> do
    expect t ("aliasOf " <> show a.lang) (Just a.canonical) (aliasOf a.lang)
    expect t ("normalize ```" <> a.lang)
      ("```" <> a.canonical <> "\nbody\n```")
      (normalize ("```" <> a.lang <> "\nbody\n```"))
  for_ unaliased \lang ->
    expect t ("aliasOf " <> show lang) Nothing (aliasOf lang)
  for_ cases \c ->
    expect t ("normalize: " <> c.label) c.out (normalize c.input)
