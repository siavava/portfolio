<template>
  <div
    class="alert-container"
    :class="type"
  >
    <div class="title-container">
      <!-- <Icon :type="type" class="alert-icon" /> -->
      <span class="title">
        {{ title || type }}
      </span>
    </div>
    <slot id="alert-content" />
  </div>
</template>

<script lang="ts">
export default {
  name: "Alert",
  props: {
    type: {
      type: String,
      default: "info",
      validator: (value: string) => [
        "info", "success", "error", "warning", "critical",
      ].includes(value),
    },
    title: {
      type: String,
      default: "",
    },
  },
}
</script>

<style lang="sass">
@use "@/styles/colors"
@use "@/styles/typography"

.alert-container

  // @each $name, $value in colors.$dark-palette
  //   --#{$name}: #{rgba(red($value), green($value), blue($value), alpha($value))}

  margin: 1em 0
  padding: 1rem
  border-radius: 0.5rem
  position: relative

  // border: 0.5px solid transparent // var(--border-color)
  border: 0.5px solid var(--border-color)

  // filter brightness
  // :is(.three-mode, .four-mode, .five-mode, .six-mode) &
  //   filter: brightness(0.8)
  //   opacity: 0.7

  .prose-ul
    font-size: inherit !important

    li::before
      color: inherit !important

  .alert-icon
    width: 1.5em
    height: 1.5em
    margin-right: 0.5em
    padding-bottom: 0.25em

  .title-container
    margin-bottom: 1em
    display: flex
    flex-direction: row

    .title
      font-weight: 600
      font-family: typography.font("monospace")
      text-transform: uppercase
      font-size: 0.8em
      margin: 0em 0 0.5em 0
      border-bottom: 1px dotted
      opacity: 0.5
      width: fit-content

  &:hover
    & > .title-container > .title
      opacity: 1

  &.info
    background-color: var(--info-background) !important
    color: var(--info-foreground) !important

    & > .paragraph
      color: var(--info-foreground) !important

  &.success
    background-color: var(--success-background)
    color: var(--success-foreground)

    & > .paragraph
      color: var(--success-foreground) !important

  &.error
    background-color: var(--error-background) !important
    color: var(--error-foreground) !important

    & > .paragraph
      color: var(--error-foreground) !important

  &.warning
    background-color: var(--warning-background)
    color: var(--warning-foreground)

    & > .paragraph
      color: var(--warning-foreground) !important

  &.critical
    background-color: var(--critical-background) !important
    color: var(--critical-foreground) !important

    & > .paragraph
      color: var(--critical-foreground) !important

  & > .paragraph
    &:is(:last-of-type)
      padding-bottom: 5em !important
      background: yellow !important

</style>
