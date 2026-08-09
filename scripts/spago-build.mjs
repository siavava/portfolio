/**
 * Runs `spago build --pure` with a CI-aware global cache.
 *
 * spago clones the purescript registry repos into its global cache
 * (`~/.cache/spago`) whenever that cache is cold — `--pure` does not skip
 * the initial clone, and CI home directories are always cold. On CI the
 * cache relocates into `node_modules/.cache`, which Vercel persists
 * across deployments, so the clone happens once and warm builds skip it.
 */
import { spawnSync } from "node:child_process"
import { join } from "node:path"

const env = { ...process.env }
if ((env.VERCEL || env.CI) && !env.XDG_CACHE_HOME)
  env.XDG_CACHE_HOME = join(process.cwd(), "node_modules", ".cache", "xdg")

const spago = join(process.cwd(), "node_modules", ".bin", "spago")
const { status } = spawnSync(spago, ["build", "--pure"], { stdio: "inherit", env })
process.exit(status ?? 1)
