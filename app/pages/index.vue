<template lang="pug">
main
  .map-slot
    ClientOnly
      InterestMap
  .below-map(:class="{ revealed: reveal.settled }", :style="slideStyle")
    NameBar(v-if="profile", :profile)
    IntroSection
    MediaSection(v-if="profile", :profile)
    ReviewsSection
    DreamTracker
    AppFooter(v-if="profile", :profile)
</template>

<script lang="ts" setup>
const { data: profile } = await useProfile()

const reveal = useMapReveal()

const slideStyle = computed(() => {
  if (reveal.settled || reveal.offset === null) return undefined
  return { transform: `translateY(${reveal.offset}px)` }
})
</script>

<style lang="sass" scoped>
main
  padding-top: 47px

  @media (max-width: 900px)
    padding-top: 0

// Reserves the graph's final footprint in the server-rendered HTML so the
// client-only mount and the height spring animate inside a fixed slot
// instead of pushing everything below (the page's main CLS source). The
// aspect-ratio mirrors the map geometry: height = 476 x min(1, width / 936).
.map-slot
  @media (min-width: 901px)
    width: calc(100% + 48px)
    margin-left: -24px
    aspect-ratio: 936 / 476
    max-height: 476px
    overflow: hidden

// Pre-hydration the content sits pulled up over the empty slot — the same
// first paint the height spring used to produce — then the map's spring
// drives it down via translate (transform moves are exempt from CLS). The
// calc mirrors the slot height: min(476px, slot width x 476 / 936).
.below-map
  @media (min-width: 901px)
    transform: translateY(calc(-1 * min(476px, (100vw + 8px) * 0.5085)))

    &.revealed
      transform: none
</style>
