-- | ## ThemeIcon
-- |
-- | The theme toggle's icon, shared by the timeline's light switch and the
-- | projects reader's topbar so the two cannot drift. Only PureScript
-- | consumes this module. @ts-internal
module App.Utils.ThemeIcon
  ( themeIconFor
  ) where

-- | The theme toggle's icon by whether the page is dark: the sun to go
-- | light, the moon to go dark.
themeIconFor :: Boolean -> String
themeIconFor dark = if dark then "lucide:sun" else "lucide:moon"
