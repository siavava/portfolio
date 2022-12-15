<template>
  <div class="container">
    <span 
      v-if="language"
      class="language"
    >
      
      {{ language }}
    </span>
    <slot />
    <div class="bottom-container">
      <div class="copy-container">
        <span class="copied-text" v-if="copied">Copied code!</span>
        <button
          class="copy-button"
          @click="copy(code)"
        >
          Copy Code
        </button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
const { copy, copied, text } = useClipboard();
</script>

<script lang="ts">
export default defineComponent({
  props: {
    code: {
      type: String,
      default: ''
    },
    language: {
      type: String,
      default: null
    },
    filename: {
      type: String,
      default: null
    },
    highlights: {
      type: Array as () => number[],
      default: () => []
    }
  }
})


</script>

<style lang="sass" scoped>
@use "../styles/colors"
@use "../styles/typography"

.container
  background: colors.color("light-background")
  position: relative
  margin-top: 1rem
  margin-bottom: 1rem
  overflow: hidden
  border-radius: 0.5rem
  padding-left: 1rem     // padding
  font: typography.font("monospace")

.language
  position: absolute
  top: 0
  right: 1em
  padding: 0.25em 0.5em
  font-size: 14px
  text-transform: capitalize
  border-bottom-right-radius: 0.25em
  border-top-left-radius: 0.25em
  color: colors.color("lightest-foreground")

.bottom-container
  display: flex
  justify-content: flex-end
  padding: 0.5rem 1rem
  border-bottom-left-radius: 0.5rem
  border-bottom-right-radius: 0.5rem

.copy-button
  font: typography.font("sans-serif")
  font-size: typography.font-size("m")
  color: colors.color("lightest-foreground")

.copy-container
  display: flex

.copied-text
  margin-right: 1em

</style>
