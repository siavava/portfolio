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
const { slideStyle } = useIndexPage({
  settled: () => reveal.settled,
  offset: () => reveal.offset,
})
</script>

<style lang="sass" scoped>
main
  padding-top: 47px

  @media (max-width: 900px)
    padding-top: 0

// 936 / 524 mirrors the interest map's geometry.
.map-slot
  @media (min-width: 901px)
    width: calc(100% + 48px)
    margin-left: -24px
    aspect-ratio: 936 / 524
    max-height: 524px
    overflow: hidden

// translate, not margin: transform moves are exempt from CLS.
.below-map
  @media (min-width: 901px)
    transform: translateY(calc(-1 * min(524px, (100vw + 8px) * 0.5598)))

    &.revealed
      transform: none
</style>
