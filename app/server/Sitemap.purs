-- | ## Sitemap
-- |
-- | Pure core behind `server/routes/sitemap.xml.ts`: assembles the sitemap
-- | entries (two static routes plus the projects collection, prioritized by
-- | kind, sorted by priority then year, both descending) and serializes them
-- | to the exact XML the `sitemap` package's `SitemapStream` produced —
-- | declaration, XSL stylesheet include, default namespaces, and per-entry
-- | `<url>` elements, byte for byte. The platform edges — the content query,
-- | the current year, WHATWG URL resolution, and JS `Number` coercion — stay
-- | in the h3 shell or the FFI companion `app/ffi/sitemap.ts`.
module App.Server.Sitemap
  ( ProjectDoc
  , SitemapArgs
  , sitemapXml
  ) where

import Prelude

import Data.Array (sortBy)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Number (isNaN)
import Data.Number.Format (fixed, toStringWith)
import Data.String (Pattern(..), Replacement(..), joinWith, replaceAll)
import Data.String.CodeUnits (take)
import Data.String.Regex (Regex, replace)
import Data.String.Regex.Flags (global, unicode)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | `new URL(url, base).toString()` — WHATWG resolution and percent-encoding.
foreign import resolveUrlImpl :: Fn2 String String String

-- | JS `Number(str)` coercion, NaN and all.
foreign import jsNumberImpl :: String -> Number

-- | One row of the projects query, coerced by the shell the way the original
-- | handler did: `date` through `String(...)`, `featured` through truthiness.
type ProjectDoc = { path :: String, date :: String, featured :: Boolean }

type SitemapArgs = { docs :: Array ProjectDoc, thisYear :: Number }

type Entry = { url :: String, changefreq :: String, priority :: Number, year :: Number }

siteDomain :: String
siteDomain = "https://amittai.studio"

-- | The whole `/sitemap.xml` body for the queried project docs.
sitemapXml :: SitemapArgs -> String
sitemapXml args =
  xmlHeader
    <> joinWith "" (map urlElement (sortEntries (entries args)))
    <> "</urlset>"

entries :: SitemapArgs -> Array Entry
entries { docs, thisYear } =
  [ { url: "/", changefreq: "monthly", priority: 1.0, year: thisYear }
  , { url: "/projects", changefreq: "monthly", priority: 0.8, year: thisYear }
  ] <> map docEntry docs
  where
  docEntry doc =
    { url: doc.path
    , changefreq: "monthly"
    , priority: if doc.featured then 0.7 else 0.5
    , year: docYear thisYear doc.date
    }

-- | `Number(String(doc.date).slice(0, 4)) || thisYear` — a falsy parse
-- | (NaN, 0, -0) falls back to the current year.
docYear :: Number -> String -> Number
docYear thisYear date =
  let
    year = jsNumberImpl (take 4 date)
  in
    if isNaN year || year == 0.0 then thisYear else year

-- | `(a, b) => b.priority - a.priority || Number(b.year) - Number(a.year)`.
-- | Both `Array.prototype.sort` and `sortBy` are stable, so ties keep the
-- | static-routes-then-query-order arrangement.
sortEntries :: Array Entry -> Array Entry
sortEntries = sortBy \a b -> compare b.priority a.priority <> compare b.year a.year

-- | The exact prelude `SitemapStream` pushes before the first entry: XML
-- | declaration, XSL stylesheet include, and the `<urlset>` open tag with
-- | the default namespaces.
xmlHeader :: String
xmlHeader =
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    <> "<?xml-stylesheet type=\"text/xsl\" href=\""
    <> escapeXmlAttr (siteDomain <> "/sitemap.xsl")
    <> "\"?>"
    <> "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\""
    <> " xmlns:news=\"http://www.google.com/schemas/sitemap-news/0.9\""
    <> " xmlns:xhtml=\"http://www.w3.org/1999/xhtml\""
    <> " xmlns:image=\"http://www.google.com/schemas/sitemap-image/1.1\""
    <> " xmlns:video=\"http://www.google.com/schemas/sitemap-video/1.1\">"

-- | One `<url>` element, mirroring `SitemapItemStream`: resolved escaped
-- | `<loc>`, `<changefreq>`, and `<priority>` via JS `toFixed(1)`.
urlElement :: Entry -> String
urlElement entry =
  "<url>"
    <> "<loc>"
    <> escapeXmlText (runFn2 resolveUrlImpl entry.url siteDomain)
    <> "</loc>"
    <> "<changefreq>"
    <> escapeXmlText entry.changefreq
    <> "</changefreq>"
    <> "<priority>"
    <> toStringWith (fixed 1) entry.priority
    <> "</priority>"
    <> "</url>"

-- | Invalid XML 1.0 characters the `sitemap` package strips from output:
-- | control characters, delete, C1 controls, surrogates, non-characters.
invalidXmlChars :: Regex
invalidXmlChars = unsafeRegex
  "[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F-\\u0084\\u0086-\\u009F\\uD800-\\uDFFF\\p{NChar}]"
  (global <> unicode)

-- | The package's `text()`: entity-escape `&`, `<`, `>` (in that order),
-- | then drop invalid XML characters.
escapeXmlText :: String -> String
escapeXmlText =
  replaceAll (Pattern "&") (Replacement "&amp;")
    >>> replaceAll (Pattern "<") (Replacement "&lt;")
    >>> replaceAll (Pattern ">") (Replacement "&gt;")
    >>> replace invalidXmlChars ""

-- | The package's `stylesheetInclude` href escaping: `&`, `"`, `<`, `>`.
escapeXmlAttr :: String -> String
escapeXmlAttr =
  replaceAll (Pattern "&") (Replacement "&amp;")
    >>> replaceAll (Pattern "\"") (Replacement "&quot;")
    >>> replaceAll (Pattern "<") (Replacement "&lt;")
    >>> replaceAll (Pattern ">") (Replacement "&gt;")
