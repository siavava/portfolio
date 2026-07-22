import type { Ref } from "vue"
import notesMeta from "~/assets/notes-meta.json"

interface ReferencedDoc {
  references?: string[]
  repo?: string
  url?: string
}

interface Reference {
  href: string
  title: string
  notes?: boolean
}

const SUBJECT_LABELS: Record<string, string> = {
  "/algorithms": "Algorithms",
  "/computer-architecture": "Computer Architecture",
  "/artificial-intelligence": "Artificial Intelligence",
  "/natural-language-processing": "Natural Language Processing",
  "/linear-algebra": "Linear Algebra",
  "/deep-learning": "Deep Learning",
}

/** Name a project link by what it actually is, not a generic "live site". */
function urlTitle(url: string): string {
  if (url.includes("huggingface.co")) return "Dataset"
  if (url.includes("leetcode.com")) return "LeetCode profile"
  if (url.endsWith(".pdf")) return "Project report"
  if (url.includes("drive.google.com")) return "Publication"
  if (url.includes("/docs")) return "Documentation"
  if (/amittai\.space\/./.test(url)) return "Article"
  return "Live site"
}

/**
 * ## useProjectReferences
 *
 * The reader's end-of-article reference list. The project's
 * own repo and live link lead; frontmatter URLs into the notes
 * site follow, resolved against the build-time notes index for
 * their real titles (subject-index pages fall back to a small
 * label map).
 *
 * ### Parameters
 *
 * | Name | Type | Description |
 * | --- | --- | --- |
 * | `selected` | `Ref<ReferencedDoc \| null>` | The open project |
 *
 * ### Returns
 *
 * | Name | Type | Description |
 * | --- | --- | --- |
 * | `references` | `ComputedRef<Reference[]>` | Ordered reference entries |
 */
export function useProjectReferences(selected: Ref<ReferencedDoc | null>) {
  const projectRefs = computed<Reference[]>(() => {
    const out: Reference[] = []
    const repo = selected.value?.repo
    const url = selected.value?.url
    if (repo) out.push({ href: repo, title: "Project repository" })
    if (url) {
      const href = url.endsWith(".pdf") ? `${url}#view=FitV&zoom=page-fit` : url
      out.push({ href, title: urlTitle(url) })
    }
    return out
  })

  const references = computed<Reference[]>(() => {
    const refs = selected.value?.references ?? []
    const notes = refs.map((href) => {
      let path: string
      try { path = new URL(href).pathname.replace(/\/+$/, "") } catch { path = href.replace(/\/+$/, "") }
      const meta = (notesMeta as Record<string, NotesMeta>)[path]
      if (meta) return { href, title: meta.title, notes: true }
      return { href, title: SUBJECT_LABELS[path] ?? path, notes: true }
    })
    return [...projectRefs.value, ...notes]
  })

  return { references }
}
