/** Archive entry shape shared by the bookshelf and the projects page. */

interface ProjectItem {
  path: string
  title: string
  /** Hand-length one-sentence summary from frontmatter. */
  summary: string
  tag: string
  year: number
  date: string
  repo?: string
  url?: string
  featured?: boolean
  tech?: string[]
}
