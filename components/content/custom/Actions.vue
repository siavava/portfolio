<template>
  <div class="buttons-container">
    <button id="menu-button" @click.prevent="() => toggleMenu()" class="menu-button column-item emphasized">
     {{ "Menu" }}
    </button>
    <span class="divider"/>
    <button @click="toggleColorMode" class="selector">
      <div class="icon">
        <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="a" x1="814.98" x2="881.02" y1="235.19" y2="235.19" gradientTransform="matrix(1.3745 0 0 1.3633 -317.33 -85.443)" gradientUnits="userSpaceOnUse">
              <stop stop-color="var(--foreground)" offset="0"/>
              <stop stop-color="var(--background)" offset="1"/>
            </linearGradient>
          </defs>
          <path
            d="M878.98 235.19c.012 17.094-13.851 30.957-30.957 30.957s-30.969-13.863-30.957-30.957c-.012-17.094 13.851-30.957 30.957-30.957s30.969 13.863 30.957 30.957z"
            color="#000000"
            fill="url(#a)"
            stroke="var(--foreground)"
            stroke-width="5.6502"
            transform="matrix(.17626 0 0 .17771 -141.52 -33.795)"
          />
        </svg>
      </div>
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

.column-item.menu-button
  line-height: 1.3
  background: transparent
  color: var(--border-color)
  font-family: typography.font("sans-serif")
  font-size: 1em

  &.emphasized
    color: var(--lightest-foreground)

.buttons-container
  display: flex
  // gap: 2em
  padding: 0

.divider
  background: var(--border-color)
  width: 0.5px
  height: 1.5em
  margin: 0 30px

.selector
  color: var(--lightest-foreground)
  background: transparent
  font-size: typography.font-size("xxs")
  font-weight: 600
  transition: all 2s ease

  margin: 0 20px 0 10px


  &:hover
    cursor: pointer

  // dont show outline when selected
  &:focus
    outline: none

  display: flex
  align-items: center
  justify-content: center
  width: 20px
  height: 20px

.icon
  // height: 100%
  height: 30px
  aspect-ratio: 1/1


  svg
    width: 100% !important 
    height: 100% !important

</style>
