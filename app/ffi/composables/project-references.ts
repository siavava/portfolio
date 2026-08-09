/**
 * Typed FFI implementations for `App.Composables.ProjectReferences` —
 * the build-time notes index and the document/URL accessors behind the
 * reference assembly.
 */
import notesMeta from "../../assets/notes-meta.json"

interface ReferencedDoc {
  references?: string[]
  repo?: string
  url?: string
}

export const repoOfImpl = (doc: ReferencedDoc): string | null => doc.repo ?? null

export const urlOfImpl = (doc: ReferencedDoc): string | null => doc.url ?? null

export const referencesOfImpl = (doc: ReferencedDoc): string[] => doc.references ?? []

export const notesTitleImpl = (path: string): string | null => {
  const meta = (notesMeta as Record<string, NotesMeta>)[path]
  return meta ? meta.title : null
}

export const pathnameOfImpl = (href: string): string | null => {
  try {
    return new URL(href).pathname
  } catch {
    return null
  }
}
