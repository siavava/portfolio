<template lang="pug">
span.bio-target(
  :class="{ active: isActive }",
  @mouseenter="connections.activate(names)",
  @mouseleave="connections.deactivate()",
)
  slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** One or more map node names, comma-separated. */
  node: string
}>()

const connections = useConnections()

const names = computed(() =>
  props.node.split(",").map(name => name.trim()).filter(Boolean))

const isActive = computed(() =>
  names.value.some(name => connections.activeNames.includes(name)))
</script>

<style lang="sass" scoped>
.bio-target
  border-bottom: 1px dashed var(--divider)
  cursor: default
  transition: color 0.2s ease

  &.active
    color: var(--foreground-strong)
</style>
