  <template>
  <nav>
    <TransitionGroup :component="null">
      <Transition
        class="fadedown"
        :timeout="timeout"
      >
        <div class="nav-inner">
          <Logo class="logo"/>
        </div>
      </Transition>
    </TransitionGroup>
    <NavLinks />
  </nav>
</template>

<script lang="ts" setup>
import { loaderDelay as timeout } from '~/src/utils';
</script>

<script lang="ts">
  export default {
    name: "Nav",
  }
</script>

<style lang="sass" scoped>

@use "~/styles/colors"
@use "~/styles/typography"
@use "~/styles/geometry"
@use "~/styles/mixins"
@use "~/styles/transitions"


nav
  @include mixins.flex-between
  position: relative
  width: 100%
  max-width: 1600px
  color: colors.color("lightest-slate")
  font-family: typography.font("font-mono")
  counter-reset: item 0
  z-index: 12
  float: right
  margin: 0 auto
  overflow: none




.nav-inner
  width: auto
  height: auto
  color: colors.color("green")
  margin-left: 10px
  margin-right: -5rem

/* Fade down */
.fadedown-enter 
  opacity: 0.01
  transform: translateY(-20px)
  transition: opacity 300ms geometry.var("default-easing"), transform 300ms geometry.var("default-easing")

.fadedown-enter-active 
  opacity: 1
  transform: translateY(0px)
  transition: opacity 300ms geometry.var("default-easing"), transform 300ms geometry.var("default-easing")

</style>
