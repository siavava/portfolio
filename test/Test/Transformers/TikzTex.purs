-- | Cases for the TeX-source munging of the build-time TikZ renderer,
-- | recorded from the TypeScript `transformers/tikz/tex.ts`, `preamble.ts`,
-- | and `render.ts` before the move: `\definecolor` hoisting (inside an
-- | option list, CRLF, none), the operator preamble lines, the exact
-- | document strings with and without 3-D setup, and the package matrix.
module Test.Transformers.TikzTex (suite) where

import Prelude

import App.Transformers.Tikz.Tex
  ( Operator
  , hoistDefineColor
  , operatorPreamble
  , texDocument
  , texPackages
  , tikzLibraries
  )
import Effect (Effect)
import Test.Harness (Tally, expect)

operators :: Array Operator
operators =
  [ { name: "\\argmax", body: "\\operatorname*{arg\\,max}" }
  , { name: "\\OPT", body: "\\operatorname{OPT}" }
  ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "hoistDefineColor: inside an option list"
    "\\definecolor{myblue}{RGB}{30,60,200}\n\\begin{tikzpicture}[\n  node distance=2cm]\n\\node[fill=myblue] {x};\n\\end{tikzpicture}"
    ( hoistDefineColor
        "\\begin{tikzpicture}[\n  \\definecolor{myblue}{RGB}{30,60,200}\n  node distance=2cm]\n\\node[fill=myblue] {x};\n\\end{tikzpicture}"
    )
  expect t "hoistDefineColor: CRLF line ends"
    "\\definecolor{a}{rgb}{1,0,0}\n\\begin{tikzpicture}\r\n\\draw (0,0) -- (1,1);\r\n\\end{tikzpicture}"
    ( hoistDefineColor
        "\\definecolor{a}{rgb}{1,0,0}\r\n\\begin{tikzpicture}\r\n\\draw (0,0) -- (1,1);\r\n\\end{tikzpicture}"
    )
  expect t "hoistDefineColor: two definitions, tabs and trailing spaces"
    "\\definecolor{c1}{HTML}{FF0000}\n\\definecolor{c2}{gray}{0.5}\n\\begin{tikzpicture}[\nscale=2]\n\\end{tikzpicture}"
    ( hoistDefineColor
        "\\begin{tikzpicture}[\n\t\\definecolor{c1}{HTML}{FF0000}  \n  \\definecolor{c2}{gray}{0.5}\t\nscale=2]\n\\end{tikzpicture}"
    )
  expect t "hoistDefineColor: no definitions"
    "\\begin{tikzpicture}\n\\draw (0,0) circle (1);\n\\end{tikzpicture}"
    (hoistDefineColor "\\begin{tikzpicture}\n\\draw (0,0) circle (1);\n\\end{tikzpicture}")
  expect t "hoistDefineColor: mid-line definition stays"
    "\\begin{tikzpicture}\n\\node {a}; \\definecolor{x}{rgb}{0,0,1}\n\\end{tikzpicture}"
    ( hoistDefineColor
        "\\begin{tikzpicture}\n\\node {a}; \\definecolor{x}{rgb}{0,0,1}\n\\end{tikzpicture}"
    )
  expect t "hoistDefineColor: definition on the last line, no newline"
    "\\definecolor{z}{rgb}{0,1,0}\n\\draw (0,0);\n"
    (hoistDefineColor "\\draw (0,0);\n\\definecolor{z}{rgb}{0,1,0}")
  expect t "hoistDefineColor: nested braces are not a definition"
    "\\definecolor{a}{rgb}{{1},0,0}\n\\draw;"
    (hoistDefineColor "\\definecolor{a}{rgb}{{1},0,0}\n\\draw;")
  expect t "hoistDefineColor: empty code" "" (hoistDefineColor "")
  expect t "operatorPreamble: one %-terminated line per operator"
    "\\providecommand{\\argmax}{\\operatorname*{arg\\,max}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%"
    (operatorPreamble operators)
  expect t "operatorPreamble: no operators" "" (operatorPreamble [])
  expect t "texDocument without setup"
    "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%\n\\begin{tikzpicture}\n\\end{tikzpicture}\n\\end{document}"
    ( texDocument
        { preamble: "\\providecommand{\\OPT}{\\operatorname{OPT}}%"
        , setup: ""
        , code: "\\begin{tikzpicture}\n\\end{tikzpicture}"
        }
    )
  expect t "texDocument with setup"
    "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%\n\\tdplotsetmaincoords{70}{110}\n\\begin{tikzpicture}[tdplot_main_coords]\n\\end{tikzpicture}\n\\end{document}"
    ( texDocument
        { preamble: "\\providecommand{\\OPT}{\\operatorname{OPT}}%"
        , setup: "\\tdplotsetmaincoords{70}{110}"
        , code: "\\begin{tikzpicture}[tdplot_main_coords]\n\\end{tikzpicture}"
        }
    )
  expect t "texDocument two setup lines, empty preamble"
    "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\n\\tdplotsetmaincoords{60}{120}\n\\tdplotsetrotatedcoords{0}{0}{0}\n\\draw;\n\\end{document}"
    ( texDocument
        { preamble: ""
        , setup: "\\tdplotsetmaincoords{60}{120}\n\\tdplotsetrotatedcoords{0}{0}{0}"
        , code: "\\draw;"
        }
    )
  expect t "texPackages: plain picture" []
    (texPackages { setup: "", code: "\\begin{tikzpicture}\\draw;\\end{tikzpicture}" })
  expect t "texPackages: math" [ "amsmath", "amssymb" ]
    (texPackages { setup: "", code: "\\node {$x$};" })
  expect t "texPackages: tikzcd" [ "amsmath", "amssymb", "tikz-cd" ]
    (texPackages { setup: "", code: "\\begin{tikzcd} A \\arrow[r] & B \\end{tikzcd}" })
  expect t "texPackages: tikzcd with math" [ "amsmath", "amssymb", "tikz-cd" ]
    (texPackages { setup: "", code: "\\begin{tikzcd} $A$ \\end{tikzcd}" })
  expect t "texPackages: setup only" [ "tikz-3dplot" ]
    (texPackages { setup: "\\tdplotsetmaincoords{70}{110}", code: "\\draw;" })
  expect t "texPackages: tdplot in code" [ "tikz-3dplot" ]
    (texPackages { setup: "", code: "\\begin{tikzpicture}[tdplot_main_coords]\\end{tikzpicture}" })
  expect t "texPackages: everything" [ "amsmath", "amssymb", "tikz-cd", "tikz-3dplot" ]
    ( texPackages
        { setup: "\\tdplotsetmaincoords{1}{2}", code: "\\begin{tikzcd} $A$ \\end{tikzcd}" }
    )
  expect t "texPackages: math and setup" [ "amsmath", "amssymb", "tikz-3dplot" ]
    (texPackages { setup: "\\tdplotsetmaincoords{1}{2}", code: "$x$" })
  expect t "tikzLibraries" "automata,positioning,arrows.meta,calc,shapes.geometric" tikzLibraries
