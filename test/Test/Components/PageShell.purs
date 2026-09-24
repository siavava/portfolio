-- | Checks for the page shell's skip link, run through its setup
-- | composable over a Vue ref (reactivity alone, no DOM): every page
-- | offers it except the timeline, which carries its own first in its tab
-- | order — and the shell follows the route as it changes.
module Test.Components.PageShell (suite) where

import Prelude

import App.Components.PageShell (setup)
import Effect (Effect)
import Test.Harness (Tally, expect)
import Vue (read, ref, write)

suite :: Tally -> Effect Unit
suite t = do
  path <- ref "/"
  shell <- setup { path: read path }

  home <- read shell.skipLink
  expect t "the home page offers the skip link" true home

  write path "/timeline"
  timeline <- read shell.skipLink
  expect t "the timeline brings its own, so the shell offers none" false timeline

  write path "/projects/portfolio"
  project <- read shell.skipLink
  expect t "leaving the timeline brings the skip link back" true project

  write path "/timelines"
  lookalike <- read shell.skipLink
  expect t "a path that only starts like the timeline's is another page" true lookalike

  write path "/notes/timeline"
  nested <- read shell.skipLink
  expect t "a page named timeline elsewhere is another page" true nested
