/**
 * ## operators
 *
 * Maps shorthand commands like
 * `\Re`, `\dim`, `\log`, etc.
 * to `\operatorname{...}` macros.
 *
 * ### Categories
 *
 * | Group    | Examples             |
 * | -------- | -------------------- |
 * | Algebra  | `\dim`, `\ker`, `\det` |
 * | Analysis | `\lim`, `\sup`, `\Var` |
 * | Trig     | `\sin`, `\cos`, `\tan` |
 * | Other    | `\Re`, `\Hom`, `\End`  |
 *
 * ### Returns
 *
 * `MacroMap` — Operator name macros.
 */
export default function operators(): MacroMap {
  const mappings = {
    "Re": "Re",
    "Res": "Res",
    "Hom": "Hom",
    "gr": "gr",
    "LND": "LND",
    "Der": "Der",
    "InnDer": "InnDer",
    "End": "End",
    "Ext": "Ext",
    "Aut": "Aut",
    "Exp": "Exp",
    "slope": "sl",
    "ad": "ad",
    "img": "img",
    "H": "H",
    "HH": "HH",

    "dim": "dim",
    "tr": "tr",
    "det": "det",
    "diag": "diag",
    "id": "id",
    "ker": "ker",
    "sgn": "sgn",
    "ord": "ord",
    "ev": "ev",

    "rank": "Rank",
    "nullity": "Nullity",
    "col": "Col",
    "row": "row",
    "im": "im",
    "spn": "Span",
    "nul": "Nul",

    "Var": "Var",
    "cov": "cov",
    "erf": "erf",
    "conv": "conv",

    "Pr": "Pr",
    "gcd": "gcd",
    "low": "low",

    // logic / model theory
    "card": "card",
    "ran": "ran",
    "lh": "lh",
    "Prb": "Prb",
    "Cons": "Cons",

    "log": "log",
    "ln": "ln",
    "sin": "sin",
    "cos": "cos",
    "tan": "tan",
    "atan": "atan",
    "atanTwo": "atan2",
    "asinh": "asinh",

    // machine / deep learning
    "softmax": "softmax",
    "softplus": "softplus",
    "ReLU": "ReLU",
    "LN": "LN",
    "KL": "KL",
    "PMI": "PMI",
    "PE": "PE",
    "LSE": "LSE",
    "FFN": "FFN",
    "Cov": "Cov",
    "clip": "clip",
    "score": "score",
    "head": "head",
    "bias": "bias",
    "aggregate": "aggregate",

    // algorithms / data structures
    "OPT": "OPT",
    "lowbit": "lowbit",
    "ccw": "ccw",
    "count": "count",
    "dist": "dist",
    "sign": "sign",
    "lca": "lca",
    "round": "round",
    "parent": "parent",
    "START": "START",
    "END": "END",

    // transformer / neural blocks
    "Attn": "Attn",
    "MHA": "MHA",
    "SA": "SA",
    "Linear": "Linear",
    "MLP": "MLP",
    "Concat": "Concat",
    "Sublayer": "Sublayer",
    "LayerNorm": "LayerNorm",
    "GELU": "GELU",
    "LeakyReLU": "LeakyReLU",
    "SwiGLU": "SwiGLU",
    "swish": "swish",
    "TopK": "TopK",
    "emb": "emb",
    "readout": "readout",
    "agg": "agg",

    // statistics / metrics / losses
    "Corr": "Corr",
    "MSE": "MSE",
    "Err": "Err",
    "std": "std",
    "mean": "mean",
    "Tr": "Tr",
    "Score": "Score",
    "PottsScore": "PottsScore",
    "PP": "PP",
    "conf": "conf",
    "acc": "acc",

    // geometry / algorithms
    "Area": "Area",
    "area": "area",
    "average": "average",
    "bound": "bound",
    "covered": "covered",
    "cross": "cross",
    "first": "first",
    "greedy": "greedy",
    "mel": "mel",
    "ninv": "ninv",
    "out": "out",
    "poly": "poly",
    "reflect": "reflect",
    "response": "response",
    "serialize": "serialize",
    "sinc": "sinc",
    "size": "size",
    "update": "update",
  }

  // Operators that take limits (subscript directly below in display mode, to
  // the side inline): `\operatorname*`. This is standard LaTeX behaviour for
  // lim / sup / inf / max / min and friends.
  const limitOps = {
    "argmax": "arg\\,max",
    "argmin": "arg\\,min",
    "argtop": "arg\\,top",
    "lim": "lim",
    "limsup": "lim\\,sup",
    "liminf": "lim\\,inf",
    "sup": "sup",
    "inf": "inf",
    "max": "max",
    "min": "min",
  }

  const named = Object.entries(mappings).reduce((acc, [key, value]) => {
    acc[`\\${key}`] = `\\operatorname{${value}}`
    return acc
  }, {} as MacroMap)
  return Object.entries(limitOps).reduce((acc, [key, value]) => {
    acc[`\\${key}`] = `\\operatorname*{${value}}`
    return acc
  }, named)
}
