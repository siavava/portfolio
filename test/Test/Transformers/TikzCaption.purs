-- | Cases for figure captions, recorded from the TypeScript
-- | `transformers/tikz/caption.ts` before the move: caption lines wrapped
-- | across comments, a caption line with no text, blocks without one, and
-- | the `$…$` placeholder round trip through stub renderers (KaTeX and
-- | `marked` output belongs to those packages), including the quirk that a
-- | literal `XMATHX<n>XMATHX` in a caption is substituted too.
module Test.Transformers.TikzCaption (suite) where

import Prelude

import App.Transformers.Tikz.Caption (Renderers, extractCaption, renderCaptionWith)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Test.Harness (Tally, expect)

stubs :: Renderers
stubs = { math: \e -> "<m>" <> e <> "</m>", inline: \s -> "<i>" <> s <> "</i>\n\n" }

suite :: Tally -> Effect Unit
suite t = do
  expect t "extractCaption: one line" (Just "A simple $x$ figure")
    (extractCaption "% caption: A simple $x$ figure\n")
  expect t "extractCaption: wrapped over comment lines"
    (Just "First line of the caption with $a + b$ math")
    ( extractCaption
        "% caption: First line of\n%   the caption with $a +\n% b$ math\n\\tdplotsetmaincoords{70}{110}\n"
    )
  expect t "extractCaption: caption line with no body text" (Just "continues here")
    (extractCaption "%% Caption:   \n% continues here\n")
  expect t "extractCaption: bare caption line only" Nothing (extractCaption "% caption:\n")
  expect t "extractCaption: comments without a caption" Nothing
    (extractCaption "% just a comment\n% another\n")
  expect t "extractCaption: empty lead" Nothing (extractCaption "")
  expect t "extractCaption: comment before the caption line" (Just "After note more")
    (extractCaption "% setup note\n% caption: After note\n% more\n")
  expect t "extractCaption: repeated caption prefix" (Just "One Two")
    (extractCaption "% caption: One\n% caption: Two\n")
  expect t "extractCaption: blank comment line inside" (Just "a b")
    (extractCaption "% caption: a\n%\n% b\n")
  expect t "extractCaption: non-comment line between" (Just "a b")
    (extractCaption "% caption: a\n\\tdplotsetmaincoords{1}{2}\n% b\n")
  expect t "extractCaption: whitespace collapsed" (Just "lots of space")
    (extractCaption "% caption:   lots    of\t\tspace  \n")
  expect t "extractCaption: uppercase, no space" (Just "upper") (extractCaption "%CAPTION:upper\n")
  expect t "extractCaption: indented comment" (Just "indented")
    (extractCaption "   % caption: indented\n  ")
  expect t "extractCaption: CRLF lines" (Just "crlf more")
    (extractCaption "% caption: crlf\r\n% more\r\n")
  expect t "extractCaption: caption mid-word is not a caption" Nothing
    (extractCaption "% the caption: here\n")
  expect t "renderCaptionWith: plain text" "<i>plain text</i>"
    (renderCaptionWith stubs "plain text")
  expect t "renderCaptionWith: one span" "<i>one <m>x</m> span</i>"
    (renderCaptionWith stubs "one $x$ span")
  expect t "renderCaptionWith: three spans in order" "<i><m>a</m> and <m>b</m> and <m>c</m></i>"
    (renderCaptionWith stubs "$a$ and $b$ and $c$")
  expect t "renderCaptionWith: odd dollar count" "<i>odd <m>a</m> b $c</i>"
    (renderCaptionWith stubs "odd $a$ b $c")
  expect t "renderCaptionWith: empty dollars are not math" "<i>cost $$ here</i>"
    (renderCaptionWith stubs "cost $$ here")
  expect t "renderCaptionWith: literal placeholder is substituted" "<i>literal  here</i>"
    (renderCaptionWith stubs "literal XMATHX0XMATHX here")
  expect t "renderCaptionWith: literal placeholder past the spans" "<i> with <m>a</m></i>"
    (renderCaptionWith stubs "XMATHX1XMATHX with $a$")
  expect t "renderCaptionWith: leading-zero placeholder" "<i><m>z</m> and <m>z</m></i>"
    (renderCaptionWith stubs "XMATHX00XMATHX and $z$")
  expect t "renderCaptionWith: newlines dropped" "<i>linebreak <m>x</m>end</i>"
    (renderCaptionWith stubs "line\nbreak $x$\n\nend")
  expect t "renderCaptionWith: math across a newline" "<i>wrapped <m>a+ b</m> math</i>"
    (renderCaptionWith stubs "wrapped $a\n+ b$ math")
  expect t "renderCaptionWith: math output is not a replacement pattern" "a $&x b"
    (renderCaptionWith { math: \e -> "$&" <> e, inline: identity } "a $x$ b")
  expect t "renderCaptionWith: inline sees the placeholders" "[<m>p</m>-<m>q</m>]"
    (renderCaptionWith { math: stubs.math, inline: \s -> "[" <> s <> "]" } "$p$-$q$")
