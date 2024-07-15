<template>
  <div class="buttons-container">
    <button id="menu-button" @click.prevent="() => toggleMenu()" class="selector">
     {{ menuOpen ? "close" : "menu" }}
    </button>
    <button @click="toggleColorMode" class="selector">
      {{ colorMode.preference === 'dark' ? 'Light' : 'Dark'}}
    </button>
  </div>
</template>

<script setup>
const colorMode = useColorMode()

const toggleColorMode = () => {
  colorMode.preference = colorMode.preference === 'dark' ? 'light' : 'dark'
}

const { menuOpen, toggleMenu } = inject('menu-options')
</script>

<style lang="sass">
@use "@/styles/typography"

.buttons-container
  display: flex
  gap: 2em

  padding: 0 1em

  @media screen and (max-width: 960px)
    gap: 1em
  
.selector
  color: var(--lightest-foreground)
  // background-color: var(--background)
  background: transparent

  font-family: typography.font("sans-serif")

  text-transform: uppercase
  border-radius: 1rem
  padding: 0 0.25rem

  font-size: typography.font-size("xxs")

  font-weight: 600

  border: 0.5px solid var(--border-color)
  transition: all 2s ease

  &:hover
    // border: 1px solid var(--border-color)
    cursor: pointer

  // dont show outline when selected
  &:focus
    outline: none

</style>
