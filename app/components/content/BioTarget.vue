<template lang="pug">
span.bio-target(
  :class="{ active: isActive }",
  @mouseenter="enter",
  @mouseleave="leave",
)
  slot
</template>

<script lang="ts" setup>
const props = defineProps<{
  /** One or more map node names, comma-separated. */
  node: string
}>()

const connections = useConnections()

const { isActive, enter, leave } = useBioTarget({
  node: () => props.node,
  activeNames: () => connections.activeNames,
  activate: connections.activate,
  deactivate: connections.deactivate,
})
</script>

<style lang="sass" scoped>
.bio-target
  border-bottom: 1px dashed var(--divider)
  cursor: default
  transition: color 0.2s ease

  &.active
    color: var(--foreground-strong)
</style>
