/**
 * ## useInterestLayout — polar layout for the interest map on a 936×792
 * canvas. Hand shim over `InterestLayout.purs`: restores the default
 * scale and casts onto the ambient MapLayout type, whose optional fields
 * the generated record types model as `| null`.
 */
import { type BranchIn, interestLayoutJs } from "#purs/App.Composables.Map.InterestLayout"

export const useInterestLayout = (branches: InterestBranch[], scale = 1): MapLayout =>
  interestLayoutJs(branches as unknown as BranchIn[], scale) as unknown as MapLayout
