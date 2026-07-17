<!--
  Plain HTML template by necessity: nuxt-og-image inlines the image as
  a base64 data URI at build time, and Pug's attribute lexer is
  quadratic on megabyte-long attribute values — it stalls the build.
-->
<template>
  <div style="font-weight: 500" :style="frame">
    <img src="/og-portrait.jpg" :style="photo">
    <div :style="text">
      <div :style="name">{{ title }}</div>
      <div :style="tagline">{{ description }}</div>
      <div :style="site">amittai.studio</div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import type { CSSProperties } from "vue"

defineProps<{
  title: string
  description: string
}>()

const frame: CSSProperties = {
  width: "1200px",
  height: "630px",
  display: "flex",
  position: "relative",
  backgroundColor: "#37474c",
  fontFamily: "Proxima Soft",
  fontWeight: 500,
}

const photo: CSSProperties = {
  position: "absolute",
  top: "0",
  left: "0",
  width: "1200px",
  height: "675px",
  objectFit: "cover",
}

const text: CSSProperties = {
  position: "absolute",
  top: "0",
  left: "0",
  width: "620px",
  height: "630px",
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  padding: "0 72px",
}

const name: CSSProperties = {
  fontSize: "64px",
  color: "#ffffff",
  lineHeight: 1.15,
}

const tagline: CSSProperties = {
  marginTop: "24px",
  fontSize: "28px",
  lineHeight: 1.45,
  color: "rgba(255, 255, 255, 0.72)",
}

const site: CSSProperties = {
  marginTop: "40px",
  fontSize: "22px",
  color: "rgba(255, 255, 255, 0.5)",
}
</script>
