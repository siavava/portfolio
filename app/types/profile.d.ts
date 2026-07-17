/** Profile data shared by the name bar, subscribe panel, and footer. */

interface SocialLink {
  label: string
  icon: string
  url: string
  /** Brand accent shown on hover. */
  color: string
}

interface SiteVersion {
  label: string
  url: string
}

interface ProfileData {
  name: string
  email: string
  location: string
  site: string
  version: string
  versions: SiteVersion[]
  blurb: string
  socials: SocialLink[]
}
