/**
 * Golden-fixture harness for the PureScript port.
 *
 * `bun scripts/purs-golden.mjs record` runs the reference implementation and
 * writes every case's result to scripts/purs-golden.json. After the port,
 * `bun scripts/purs-golden.mjs check` re-runs the same cases against the
 * (now PureScript-backed) modules and diffs them against the recording.
 */

import { decodeShareText, encodeShareText, transcode } from "../app/utils/coder.ts"
import { formatMonthYear, titleCase } from "../app/utils/format.ts"
import { readFileSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

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

const run = (c) => {
  if (c.kind === "transcode") return transcode(c.input, c.from, c.to, { preserveWhitespace: c.preserveWhitespace })
  if (c.kind === "share") return { encoded: encodeShareText(c.input), roundTrip: decodeShareText(encodeShareText(c.input)) }
  if (c.kind === "shareDecode") return { decoded: decodeShareText(c.input) }
  if (c.kind === "format") return { out: titleCase(c.input) }
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
