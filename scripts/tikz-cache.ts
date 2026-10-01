/**
 * Keeps the rendered TikZ figures (`.cache/tikz`) in Vercel Blob between
 * production builds, independent of the build cache, which a Node or
 * package-manager change, a month without builds, or a cacheless redeploy
 * would wipe.
 *
 *   bun scripts/tikz-cache.ts restore   # before the build
 *   bun scripts/tikz-cache.ts save      # after it
 *
 * The whole cache travels as one gzipped JSON archive, so a build costs one
 * download and, only when figures were added, one upload — a blob per
 * figure would spend the Hobby plan's monthly operations on the first fill.
 * The upload holds only the figures this build's prerender served (recorded
 * by `server/api/tikz/[hash].get.ts`), so figures no page shows any more
 * drop out; with no record, it keeps every figure on disk.
 * Without Blob credentials (any local build) both steps do nothing, and a
 * Blob failure is logged and skipped: the worst case is a build that
 * re-renders every figure.
 */
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs"
import { get, put } from "@vercel/blob"
import { gunzipSync, gzipSync } from "node:zlib"
import { createHash } from "node:crypto"
import { join } from "node:path"

import { TIKZ_CACHE_DIR } from "../transformers/tikz/cache"

const ARCHIVE = "tikz-cache.json.gz"
/** What the stored archive holds, so a save can tell nothing changed. */
const RESTORED = join(TIKZ_CACHE_DIR, "..", "tikz.restored")
/** The figures this build's prerender served. */
const USED = join(TIKZ_CACHE_DIR, "..", "tikz.used")

const log = (message: string): void => console.log(`[tikz-cache] ${message}`)

const figures = (): string[] =>
  existsSync(TIKZ_CACHE_DIR) ? readdirSync(TIKZ_CACHE_DIR).filter(name => name.endsWith(".html")).sort() : []

const fingerprint = (names: string[]): string =>
  createHash("sha256").update(names.join("\n")).digest("hex")

async function restore(): Promise<void> {
  rmSync(USED, { force: true })
  const found = await get(ARCHIVE, { access: "private", useCache: false })
  if (found?.statusCode !== 200 || !found.stream) {
    log("no archive yet; every figure renders")
    return
  }
  const archive: Record<string, string> = JSON.parse(
    gunzipSync(Buffer.from(await new Response(found.stream).arrayBuffer())).toString("utf8"),
  )
  mkdirSync(TIKZ_CACHE_DIR, { recursive: true })
  let written = 0
  for (const [name, html] of Object.entries(archive)) {
    const path = join(TIKZ_CACHE_DIR, name)
    if (!existsSync(path)) {
      writeFileSync(path, html)
      written++
    }
  }
  writeFileSync(RESTORED, fingerprint(Object.keys(archive).sort()))
  log(`restored ${written} of ${Object.keys(archive).length} figures`)
}

/** The figures to store: those the prerender served, or all on disk without a record. */
function kept(): string[] {
  const onDisk = figures()
  const used = new Set(existsSync(USED) ? readFileSync(USED, "utf8").split("\n").filter(Boolean) : [])
  if (used.size === 0) return onDisk
  const names = onDisk.filter(name => used.has(name))
  log(`keeping ${names.length} figures the pages use; pruning ${onDisk.length - names.length}`)
  return names
}

async function save(): Promise<void> {
  const names = kept()
  if (names.length === 0) {
    log("no figures to save")
    return
  }
  const fp = fingerprint(names)
  if (existsSync(RESTORED) && readFileSync(RESTORED, "utf8") === fp) {
    log(`unchanged (${names.length} figures); skipping upload`)
    return
  }
  const archive = Object.fromEntries(names.map(name => [name, readFileSync(join(TIKZ_CACHE_DIR, name), "utf8")]))
  const body = gzipSync(JSON.stringify(archive))
  await put(ARCHIVE, body, {
    access: "private",
    allowOverwrite: true,
    addRandomSuffix: false,
    contentType: "application/gzip",
  })
  writeFileSync(RESTORED, fp)
  log(`saved ${names.length} figures (${(body.length / 1024).toFixed(0)} KiB)`)
}

const step = process.argv[2]
if (step !== "restore" && step !== "save") {
  console.error("usage: bun scripts/tikz-cache.ts restore|save")
  process.exit(1)
}

if (!process.env.BLOB_READ_WRITE_TOKEN && !process.env.BLOB_STORE_ID) {
  log("no Blob credentials; skipping")
} else {
  try {
    await (step === "restore" ? restore() : save())
  } catch (error) {
    log(`${step} failed, continuing without it: ${error instanceof Error ? error.message : String(error)}`)
  }
}
