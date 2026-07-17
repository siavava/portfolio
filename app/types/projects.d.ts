/** Archive entries rendered as spines on the bookshelf panel. */

interface ProjectItem {
  title: string
  blurb: string
  repo: string
  tag: string
  year: number
  /** Part of the default rotation the shelf highlights on load. */
  featured?: boolean
}

interface ProjectsData {
  items: ProjectItem[]
}
