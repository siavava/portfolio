-- | Locked-down cases for the notes-meta build core: which notes-site URLs a
-- | markdown text yields, how each reduces to a WHATWG pathname without
-- | trailing slashes, the dedupe-and-sort across texts, the kept/missing
-- | split, and the exact summary line the script logs.
module Test.Build.NotesMeta (suite) where

import Prelude

import App.Build.NotesMeta (notePaths, pruneNotes, referencedPaths, summaryLine)
import Data.Foldable (for_)
import Effect (Effect)
import Test.Harness (Tally, expect)

site :: String
site = "https://notes.amittai.studio"

terminators :: Array String
terminators = [ " ", "\n", "\t", "\"", "'", ")", "]", "}", ">", "," ]

suite :: Tally -> Effect Unit
suite tally = do
  expect tally "markdown link" [ "/algo/graphs" ]
    (notePaths ("[x](" <> site <> "/algo/graphs)"))
  for_ terminators \t ->
    expect tally ("terminator " <> show t) [ "/a" ]
      (notePaths (site <> "/a" <> t <> "tail"))
  expect tally "html attribute" [ "/a/b" ]
    (notePaths ("<a href=\"" <> site <> "/a/b\">x</a>"))
  expect tally "match order kept, duplicates kept"
    [ "/b", "/a", "/b" ]
    (notePaths ("see " <> site <> "/b and [x](" <> site <> "/a), " <> site <> "/b"))
  expect tally "no links" [] (notePaths "plain prose, https://example.com/a")

  expect tally "one trailing slash" [ "/a" ] (notePaths (site <> "/a/"))
  expect tally "many trailing slashes" [ "/a" ] (notePaths (site <> "/a///"))
  expect tally "inner slashes kept" [ "/a//b" ] (notePaths (site <> "/a//b/"))
  expect tally "query and hash dropped" [ "/a" ] (notePaths (site <> "/a?x=1#h"))
  expect tally "slash before query stripped" [ "/a" ] (notePaths (site <> "/a/?x=1"))
  expect tally "hash only" [ "/a/b" ] (notePaths (site <> "/a/b#sec"))
  expect tally "bare double slash strips to empty" [ "" ] (notePaths (site <> "//"))

  expect tally "dot segments resolve" [ "/a/c" ] (notePaths (site <> "/a/./b/../c"))
  expect tally "non-ASCII percent-encoded" [ "/caf%C3%A9" ] (notePaths (site <> "/café"))
  expect tally "existing escapes kept" [ "/a%20b" ] (notePaths (site <> "/a%20b"))

  expect tally "http ignored" [] (notePaths "http://notes.amittai.studio/a")
  expect tally "other host ignored" [] (notePaths "https://amittai.studio/a")
  expect tally "lookalike host ignored" []
    (notePaths "https://notes.amittai.studio.example.com/a")
  expect tally "bare host ignored" [] (notePaths site)
  expect tally "root with nothing after ignored" [] (notePaths (site <> "/ next"))
  expect tally "host is case-sensitive" [] (notePaths "https://Notes.amittai.studio/a")

  expect tally "dedupe across texts, code-unit sort" [ "/B", "/a", "/c" ]
    ( referencedPaths
        [ site <> "/c " <> site <> "/a"
        , "[x](" <> site <> "/a/) " <> site <> "/B"
        , "nothing here"
        ]
    )
  expect tally "no texts" [] (referencedPaths [])
  expect tally "slash variants collapse" [ "/a" ]
    (referencedPaths [ site <> "/a", site <> "/a/", site <> "/a?x#y" ])

  expect tally "kept in referenced order, missing counted"
    { kept: [ "/a", "/c" ], missing: 2 }
    (pruneNotes { referenced: [ "/a", "/b", "/c", "/d" ], available: [ "/c", "/x", "/a" ] })
  expect tally "empty referenced" { kept: [], missing: 0 }
    (pruneNotes { referenced: [], available: [ "/a" ] })
  expect tally "empty snapshot" { kept: [], missing: 2 }
    (pruneNotes { referenced: [ "/a", "/b" ], available: [] })
  expect tally "all kept" { kept: [ "/a", "/b" ], missing: 0 }
    (pruneNotes { referenced: [ "/a", "/b" ], available: [ "/b", "/a" ] })

  expect tally "summary without missing"
    "notes-meta: 3 referenced → 3 kept (from 120 in full snapshot)"
    (summaryLine { referenced: 3, kept: 3, missing: 0, total: 120 })
  expect tally "summary with missing"
    ( "notes-meta: 5 referenced → 3 kept, 2 not in snapshot (path fallback)"
        <> " (from 120 in full snapshot)"
    )
    (summaryLine { referenced: 5, kept: 3, missing: 2, total: 120 })
  expect tally "summary all zero"
    "notes-meta: 0 referenced → 0 kept (from 0 in full snapshot)"
    (summaryLine { referenced: 0, kept: 0, missing: 0, total: 0 })
