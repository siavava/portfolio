/**
 * Golden-fixture harness for the PureScript port.
 *
 * `bun scripts/purs-golden.mjs record` runs the reference implementation and
 * writes every case's result to scripts/purs-golden.json. After the port,
 * `bun scripts/purs-golden.mjs check` re-runs the same cases against the
 * (now PureScript-backed) modules and diffs them against the recording.
 */

import { decodeShareText, encodeShareText, transcode } from "../app/utils/coder/index.ts"
import { formatMonthYear, titleCase } from "../.purs-shims/utils/format.ts"
import { hashLabel, spineStyle } from "../.purs-shims/utils/spines.ts"
import { readFileSync, writeFileSync } from "node:fs"
import { renderInlineMath, renderMarkdownMath } from "../.purs-shims/utils/markdown-math.ts"
import { fileURLToPath } from "node:url"
import { renderTex } from "../app/utils/katex/index.ts"

const GOLDEN = fileURLToPath(new URL("./purs-golden.json", import.meta.url))

const FORMATS = ["letters", "binary", "decimal", "hex"]

const SAMPLES = [
  "",
  "hi",
  "hi yo",
  "hello, world",
  "  leading and  double  spaces ",
  "line one\nline two\n\nline four",
  "naïve café — résumé",
  "emoji 🎉 and 中文 mixed",
  "01101000 01101001",
  "01101000 01101001 / 01111001 01101111",
  "0b01101000 0B01101001",
  "104 101 108 108 111",
  "68 65 6c 6c 6f",
  "0x68 0X65",
  "68656c6c6f",
  "not-binary",
  "999",
  "abc xyz",
  "0110100",
  "011010001",
  "6865c",
  "104 / 105",
  "/",
  "\t\ttabbed\tinput",
]

const cases = []
for (const from of FORMATS) {
  for (const to of FORMATS) {
    for (const input of SAMPLES) {
      for (const preserveWhitespace of [false, true]) {
        cases.push({ kind: "transcode", input, from, to, preserveWhitespace })
      }
    }
  }
}
for (const input of SAMPLES) {
  cases.push({ kind: "share", input })
}
cases.push({ kind: "shareDecode", input: "aGVsbG8" })
cases.push({ kind: "shareDecode", input: "not!!valid@@base64" })
cases.push({ kind: "format", input: "the lord of the rings" })
cases.push({ kind: "format", input: "a tale of two cities" })
cases.push({ kind: "format", input: "of mice and men" })
cases.push({ kind: "monthYear", input: "2026-08" })
cases.push({ kind: "monthYear", input: "2026" })
cases.push({ kind: "monthYear", input: "" })
for (const input of [...SAMPLES, "Attention Is All You Need", "Neural Networks", "astra", "A Very Long Book Title That Overflows The Shelf Entirely", "ゼロから作る", "🎉🎉🎉"]) {
  cases.push({ kind: "spine", input })
}
for (const input of ["", "x^2 + y^2 = z^2", "\\R^2 \\to \\N", "\\frac{a}{b}", "\\invalid{cmd", "\\qed"]) {
  cases.push({ kind: "tex", input, display: false })
  cases.push({ kind: "tex", input, display: true })
}
for (const input of ["", "# Heading\n\nSome **bold** prose with $e = mc^2$.", "$$\\sum_{i=0}^n i = \\frac{n(n+1)}{2}$$", "inline $a+b$ and\nline break", "- list\n- items", "$unclosed", "**emphasis** _under_ and *star*"]) {
  cases.push({ kind: "markdown", input })
}
for (const input of ["", "pure text", "$x^2$", "mix $a_i$ and **bold** and _em_ tails", "a < b & c > d", "snake_case_word stays put", "*star em* and **strong**", "$first$ then $second$", "$$"]) {
  cases.push({ kind: "inlineMath", input })
}

const run = (c) => {
  if (c.kind === "transcode") return transcode(c.input, c.from, c.to, { preserveWhitespace: c.preserveWhitespace })
  if (c.kind === "share") return { encoded: encodeShareText(c.input), roundTrip: decodeShareText(encodeShareText(c.input)) }
  if (c.kind === "shareDecode") return { decoded: decodeShareText(c.input) }
  if (c.kind === "format") return { out: titleCase(c.input) }
  if (c.kind === "spine") return { hash: hashLabel(c.input), style: spineStyle(c.input) }
  if (c.kind === "tex") return { out: renderTex(c.input, c.display) }
  if (c.kind === "markdown") return { out: renderMarkdownMath(c.input) }
  if (c.kind === "inlineMath") return { out: renderInlineMath(c.input) }
  return { out: formatMonthYear(c.input) }
}

const mode = process.argv[2]
if (mode === "record") {
  const results = cases.map(c => ({ case: c, result: run(c) }))
  writeFileSync(GOLDEN, JSON.stringify(results, null, 1))
  console.log(`recorded ${results.length} cases`)
} else if (mode === "check") {
  const golden = JSON.parse(readFileSync(GOLDEN, "utf8"))
  let failures = 0
  for (const entry of golden) {
    const actual = run(entry.case)
    if (JSON.stringify(actual) !== JSON.stringify(entry.result)) {
      failures++
      if (failures <= 10) {
        console.log("MISMATCH", JSON.stringify(entry.case))
        console.log("  expected:", JSON.stringify(entry.result).slice(0, 300))
        console.log("  actual:  ", JSON.stringify(actual).slice(0, 300))
      }
    }
  }
  console.log(failures === 0 ? `all ${golden.length} cases match` : `${failures} / ${golden.length} cases FAILED`)
  process.exit(failures === 0 ? 0 : 1)
} else {
  console.log("usage: bun scripts/purs-golden.mjs record|check")
  process.exit(2)
}
