-- | Locked-down cases for the sitemap route's pure core: the exact header
-- | and `<url>` element bytes, XML entity escaping, invalid-character
-- | stripping, and the priority-then-year (both descending) ordering.
-- |
-- | The pieces are then checked one by one: the three static routes and
-- | their priorities, a doc's year (the first four characters, falling
-- | back to this year on any falsy parse), the stable sort, text escaping
-- | that keeps whitespace controls but drops the characters XML 1.0
-- | forbids, attribute escaping that also covers quotes, and the whole
-- | document for a site without projects.
module Test.Server.Sitemap (suite) where

import Prelude

import App.Server.Sitemap
  ( Entry
  , SitemapArgs
  , docYear
  , entries
  , escapeXmlAttr
  , escapeXmlText
  , sitemapXml
  , sortEntries
  , urlElement
  , xmlHeader
  )
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), contains, indexOf)
import Data.String.CodeUnits (length, take)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

soh :: String
soh = "\x0001"

xmlDecl :: String
xmlDecl = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"

args :: SitemapArgs
args =
  { thisYear: 2026.0
  , docs:
      [ { path: "/projects/a&b", date: "2019-03-14", featured: false }
      , { path: "/projects/alpha", date: "2021-05-01", featured: false }
      , { path: "/projects/ctl" <> soh <> "tail", date: "2020-01-01", featured: false }
      , { path: "/projects/beta", date: "2023-11-09", featured: true }
      , { path: "/projects/gamma", date: "TBD", featured: false }
      ]
  }

upcoming :: { path :: String, date :: String, featured :: Boolean }
upcoming = { path: "/projects/next", date: "2030", featured: true }

entry :: String -> Number -> Number -> Entry
entry url priority year = { url, changefreq: "monthly", priority, year }

expectOrdered :: Tally -> String -> String -> String -> String -> Effect Unit
expectOrdered t label first second haystack =
  case indexOf (Pattern first) haystack, indexOf (Pattern second) haystack of
    Just a, Just b -> expect t label true (a < b)
    _, _ -> expect t (label <> ": both locs present") true false

suite :: Tally -> Effect Unit
suite t = do
  let xml = sitemapXml args
  expect t "xml declaration prefix" xmlDecl (take (length xmlDecl) xml)
  expectContains t "xsl stylesheet include"
    "<?xml-stylesheet type=\"text/xsl\" href=\"/sitemap.xsl\"?>"
    xml
  expectContains t "urlset open tag"
    "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" xmlns:news=\"http://www.google.com/schemas/sitemap-news/0.9\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\" xmlns:image=\"http://www.google.com/schemas/sitemap-image/1.1\" xmlns:video=\"http://www.google.com/schemas/sitemap-video/1.1\">"
    xml
  expectContains t "urlset close tag" "</urlset>" xml
  expectContains t "root entry"
    "<url><loc>https://amittai.studio/</loc><changefreq>monthly</changefreq><priority>1.0</priority></url>"
    xml
  expectContains t "projects entry"
    "<url><loc>https://amittai.studio/projects</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>"
    xml
  expectContains t "featured doc entry at 0.7"
    "<url><loc>https://amittai.studio/projects/beta</loc><changefreq>monthly</changefreq><priority>0.7</priority></url>"
    xml
  expectContains t "plain doc entry at 0.5"
    "<url><loc>https://amittai.studio/projects/alpha</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>"
    xml
  expectContains t "ampersand entity-escaped in loc"
    "<loc>https://amittai.studio/projects/a&amp;b</loc>"
    xml
  expect t "raw ampersand absent from loc" false (contains (Pattern "a&b</loc>") xml)
  expect t "control character stripped" false (contains (Pattern soh) xml)
  expectOrdered t "priority 1.0 before 0.8" "studio/</loc>" "studio/projects</loc>" xml
  expectOrdered t "priority 0.8 before 0.7" "studio/projects</loc>" "/projects/beta</loc>" xml
  expectOrdered t "priority 0.7 before 0.5" "/projects/beta</loc>" "/projects/gamma</loc>" xml
  expectOrdered t "unparseable date falls back to thisYear" "/projects/gamma</loc>"
    "/projects/alpha</loc>"
    xml
  expectOrdered t "equal priority orders by year descending" "/projects/alpha</loc>"
    "/projects/a&amp;b</loc>"
    xml

  pieces t

pieces :: Tally -> Effect Unit
pieces t = do
  expect t "the static routes lead, dated this year, then the docs in query order"
    [ entry "/" 1.0 2026.0
    , entry "/projects" 0.8 2026.0
    , entry "/timeline" 0.7 2026.0
    , entry "/projects/beta" 0.7 2023.0
    , entry "/projects/alpha" 0.5 2021.0
    ]
    ( entries
        { thisYear: 2026.0
        , docs:
            [ { path: "/projects/beta", date: "2023-11-09", featured: true }
            , { path: "/projects/alpha", date: "2021-05-01", featured: false }
            ]
        }
    )
  expect t "no docs, only the static routes" [ "/", "/projects", "/timeline" ]
    (map _.url (entries { thisYear: 2026.0, docs: [] }))

  expect t "a doc's year is its date's first four characters" 2019.0 (docYear 2026.0 "2019-03-14")
  expect t "a bare year reads as itself" 1999.0 (docYear 2026.0 "1999")
  expect t "an unparsable date falls back to this year" 2026.0 (docYear 2026.0 "TBD")
  expect t "an empty date falls back to this year" 2026.0 (docYear 2026.0 "")
  expect t "a year of zero falls back to this year" 2026.0 (docYear 2026.0 "0000-01-01")
  expect t "a date not starting with a number falls back to this year" 2026.0
    (docYear 2026.0 "20x9-01-01")

  expect t "higher priority first, then later year, ties in their original order"
    [ "b", "d", "c", "a" ]
    ( map _.url
        ( sortEntries
            [ entry "a" 0.5 2020.0
            , entry "b" 0.7 2019.0
            , entry "c" 0.5 2023.0
            , entry "d" 0.7 2019.0
            ]
        )
    )
  expect t "a featured doc dated after this year outranks the timeline route"
    [ "/", "/projects", "/projects/next", "/timeline" ]
    (map _.url (sortEntries (entries { thisYear: 2026.0, docs: [ upcoming ] })))

  expect t "text escaping covers the three markup characters" "a&amp;b&lt;c&gt;d"
    (escapeXmlText "a&b<c>d")
  expect t "an escaped < is not escaped again" "&lt;" (escapeXmlText "<")
  expect t "an existing entity's ampersand is escaped" "&amp;lt;" (escapeXmlText "&lt;")
  expect t "text escaping leaves quotes alone" "\"'" (escapeXmlText "\"'")
  expect t "tab, newline and carriage return survive" "a\tb\nc\rd" (escapeXmlText "a\tb\nc\rd")
  expect t "C0 controls other than whitespace are dropped" "ab"
    (escapeXmlText ("a" <> "\x0000" <> "\x0008" <> "\x000B" <> "\x000C" <> "\x001F" <> "b"))
  expect t "delete and the C1 controls are dropped" "ab"
    (escapeXmlText ("a" <> "\x007F" <> "\x0084" <> "\x0086" <> "\x009F" <> "b"))
  expect t "next-line (U+0085) is the one C1 control kept" ("a" <> "\x0085" <> "b")
    (escapeXmlText ("a" <> "\x0085" <> "b"))
  expect t "non-characters are dropped" "ab"
    (escapeXmlText ("a" <> "\xFFFE" <> "\xFDD0" <> "\xFFFF" <> "b"))
  expect t "ordinary non-ASCII text is kept" "café · 𝜋" (escapeXmlText "café · 𝜋")

  expect t "attribute escaping covers quotes too" "a&amp;b&quot;c&lt;d&gt;e"
    (escapeXmlAttr "a&b\"c<d>e")
  expect t "attribute escaping leaves single quotes alone" "it's" (escapeXmlAttr "it's")

  expect t "one url element: resolved loc, changefreq, one-decimal priority"
    "<url><loc>https://amittai.studio/projects/a</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>"
    (urlElement (entry "/projects/a" 0.5 2020.0))
  expect t "a loc is percent-encoded the way URL resolution encodes it"
    "<url><loc>https://amittai.studio/projects/a%20b</loc><changefreq>monthly</changefreq><priority>1.0</priority></url>"
    (urlElement (entry "/projects/a b" 1.0 2020.0))
  expect t "a site without projects: header, the three routes, close"
    ( xmlHeader
        <>
          "<url><loc>https://amittai.studio/</loc><changefreq>monthly</changefreq><priority>1.0</priority></url>"
        <>
          "<url><loc>https://amittai.studio/projects</loc><changefreq>monthly</changefreq><priority>0.8</priority></url>"
        <>
          "<url><loc>https://amittai.studio/timeline</loc><changefreq>monthly</changefreq><priority>0.7</priority></url>"
        <> "</urlset>"
    )
    (sitemapXml { thisYear: 2026.0, docs: [] })
  expect t "the header opens with the declaration and runs straight into the urlset" true
    ( take (length xmlDecl) xmlHeader == xmlDecl
        && contains (Pattern "?><urlset xmlns=") xmlHeader
    )
