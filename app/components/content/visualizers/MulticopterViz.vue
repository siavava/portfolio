<template lang="pug">
VizFrame(variant="multicopter-viz", title="Multicopter (side view)", :note="note")
  template(#caption)
    | A planar multicopter under a cascaded PD controller. Click anywhere
    | in the frame to set a waypoint: the controller cannot push sideways
    | directly, so it banks — the differential between the two orange
    | thrust arrows tips the craft, the tilted total thrust carries it
    | across, and the same arrows level it out and brake at the target.
    | Nudge kicks the craft to show the recovery; the faded line is the
    | flight path.
  template(#controls)
    button.viz-btn.primary(type="button", @click="nudge") nudge
    button.viz-btn(type="button", @click="reset") reset
  svg.viz-canvas.mc-stage(:viewBox="`0 0 ${W} ${H}`", @click="flyTo")
    line.ground(:x1="0", :y1="groundPx", :x2="W", :y2="groundPx")
    polyline.trail(:points="trailPoints")
    g.waypoint(:transform="`translate(${targetPx.x},${targetPx.y})`")
      circle(r="5.5")
      line(x1="-9", y1="0", x2="-4", y2="0")
      line(x1="4", y1="0", x2="9", y2="0")
      line(x1="0", y1="-9", x2="0", y2="-4")
      line(x1="0", y1="4", x2="0", y2="9")
    g(:transform="craftTransform")
      line.arm(:x1="-armPx", :y1="0", :x2="armPx", :y2="0")
      rect.rotor(:x="-armPx - 8", :y="-4.5", width="16", height="9")
      rect.rotor(:x="armPx - 8", :y="-4.5", width="16", height="9")
      line.thrust(:x1="-armPx", :y1="-5", :x2="-armPx", :y2="-5 - leftLen + HEAD")
      polygon.thrust-head(:points="head(-armPx, -5 - leftLen)")
      line.thrust(:x1="armPx", :y1="-5", :x2="armPx", :y2="-5 - rightLen + HEAD")
      polygon.thrust-head(:points="head(armPx, -5 - rightLen)")
      text.svg-label.thrust-label(:x="-armPx - 6", :y="-12 - leftLen") f1
      text.svg-label.thrust-label(:x="armPx + 6", :y="-12 - rightLen", text-anchor="start") f2
      circle.com(:cx="0", :cy="0", r="2.4")
    line.gravity(:x1="comX", :y1="comY + 8", :x2="comX", :y2="comY + 34 - HEAD")
    polygon.gravity-head(:points="gHead")
    text.svg-label.gravity-label(:x="comX + 6", :y="comY + 32", text-anchor="start") mg
  template(#legend)
    .viz-legend
      span
        i.swatch-thrust
        | rotor thrust (commanded)
      span
        i.swatch-gravity
        | gravity
      span
        i.swatch-trail
        | flight path
      span
        i.swatch-waypoint
        | waypoint (click to move)
</template>

<script lang="ts" setup>
const {
  W, H, HEAD, groundPx, armPx,
  targetPx, comX, comY, craftTransform,
  leftLen, rightLen, trailPoints, gHead, head,
  note, flyTo, nudge, reset,
} = useMulticopterViz()
</script>

<style lang="sass" scoped>
.multicopter-viz
  .mc-stage
    cursor: crosshair
  .arm
    stroke: var(--blue-underline)
    stroke-width: 3
  .rotor
    fill: var(--blue-highlight)
    stroke: var(--blue-underline)
    stroke-width: 1
  .com
    fill: var(--foreground)
  .thrust
    stroke: var(--orange-underline)
    stroke-width: 2.5
  .thrust-head
    fill: var(--orange-underline)
  .trail
    fill: none
    stroke: var(--blue-underline)
    stroke-opacity: 0.3
    stroke-width: 1
  .waypoint
    circle
      fill: none
      stroke: var(--green-underline)
      stroke-width: 1.2
    line
      stroke: var(--green-underline)
      stroke-width: 1.2
  .ground
    stroke: var(--lightest-foreground)
    stroke-opacity: 0.35
    stroke-width: 1
  .svg-label
    fill: var(--lightest-foreground)
    fill-opacity: 0.55
    font-family: monospace
    font-size: 9px
  .thrust-label
    fill: var(--orange-underline)
    fill-opacity: 0.85
    text-anchor: end
  .gravity-label
    fill-opacity: 0.5
  .gravity
    stroke: var(--lightest-foreground)
    stroke-opacity: 0.4
    stroke-width: 1.5
  .gravity-head
    fill: var(--lightest-foreground)
    fill-opacity: 0.4
  .swatch-thrust
    background: var(--orange-underline)
  .swatch-gravity
    background: var(--lightest-foreground)
    opacity: 0.4
  .swatch-trail
    background: var(--blue-underline)
    opacity: 0.35
  .swatch-waypoint
    background: var(--green-underline)
</style>
