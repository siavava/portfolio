-- | Checks for the contact panel's email button, run through its setup
-- | composable over Vue refs (reactivity alone, no DOM): it links to the
-- | address, reads "Email" at rest, reveals the address under the pointer
-- | and puts "Email" back when the pointer leaves, and follows the
-- | profile's address when it changes.
module Test.Components.ContactPanel (suite) where

import Prelude

import App.Components.ContactPanel (setup)
import Effect (Effect)
import Test.Harness (Tally, expect)
import Vue (read, ref, write)

suite :: Tally -> Effect Unit
suite t = do
  email <- ref "hello@example.com"
  panel <- setup { email: read email }

  href <- read panel.href
  expect t "the button links to the address" "mailto:hello@example.com" href

  resting <- read panel.label
  expect t "at rest the button reads Email" "Email" resting

  panel.enter
  hovered <- read panel.label
  expect t "under the pointer the button reveals the address" "hello@example.com" hovered

  panel.leave
  left <- read panel.label
  expect t "when the pointer leaves the button reads Email again" "Email" left

  write email "studio@example.org"
  moved <- read panel.href
  expect t "the link follows a changed address" "mailto:studio@example.org" moved

  panel.enter
  revealed <- read panel.label
  expect t "the reveal shows the changed address" "studio@example.org" revealed
