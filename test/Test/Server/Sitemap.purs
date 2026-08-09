-- | Locked-down cases for the sitemap route's pure core: the exact header
-- | and `<url>` element bytes, XML entity escaping, invalid-character
-- | stripping, and the priority-then-year (both descending) ordering.
module Test.Server.Sitemap (suite) where

import Prelude

import App.Server.Sitemap (SitemapArgs, sitemapXml)
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), contains, indexOf)
import Data.String.CodeUnits (length, take)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

-- | U+0001 — an invalid XML 1.0 character that must never reach the output.
soh :: String
soh = "\x0001"

xmlDecl :: String
xmlDecl = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"

-- | Docs arrive deliberately shuffled: the sort must float the featured doc
-- | above every plain one and order equal priorities by year descending,
-- | with the unparseable date falling back to `thisYear`.
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

-- | Assert both needles occur and `first` occurs before `second`.
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
    "<?xml-stylesheet type=\"text/xsl\" href=\"https://amittai.studio/sitemap.xsl\"?>"
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
