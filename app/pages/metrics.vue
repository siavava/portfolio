<template lang="pug">
main.metrics
  header.metrics__head
    h1.metrics__title Metrics
    p.metrics__status
      span.metrics__dot(:class="{ live: mounted && metrics.connected }")
      | {{ mounted && metrics.connected ? "live" : "connecting" }}
      span.metrics__sep |
      | {{ mounted ? metrics.activeCount : 0 }} online
      template(v-if="metrics.health")
        span.metrics__sep |
        | up {{ uptime }}
        span.metrics__sep |
        | db {{ metrics.health.dbConnected ? "ok" : "down" }}

  .metrics__ekg(aria-hidden="true")
    svg(viewBox="0 0 700 36", preserveAspectRatio="none")
      line.metrics__ekg-base(x1="0", y1="30", x2="700", y2="30")
      polyline.metrics__ekg-line(:points="ekgPoints")

  section.note-target.metrics__section
    MarginNote(label="Pulse")
    .metrics__pulse
      .metrics__counters
        .metrics__counter
          p.metrics__counter-value(:class="{ bump: bumpViews }") {{ totalViews }}
          p.metrics__counter-label page views
        .metrics__counter
          p.metrics__counter-value(:class="{ bump: bumpVisits }") {{ totalVisits }}
          p.metrics__counter-label visits logged
        .metrics__counter
          p.metrics__counter-value {{ eventsLastHour }}
          p.metrics__counter-label events / 1 hour
        .metrics__counter
          p.metrics__counter-value {{ eventsLastFive }}
          p.metrics__counter-label events / 5 min

      .metrics__chart
        .metrics__chart-bars
          .metrics__chart-col(
            v-for="bar in hourBars",
            :key="bar.hour",
            :title="`${bar.label}: ${bar.count}`",
          )
            .metrics__chart-fill(
              :class="{ current: bar.current }",
              :style="{ height: `${bar.height}%` }",
            )
        .metrics__chart-axis
          span(v-for="tick in hourTicks", :key="tick") {{ tick }}
        p.metrics__chart-caption(v-if="pulseCaption") {{ pulseCaption }}

      .metrics__heatmap
        .metrics__heatmap-row(v-for="row in heatmap", :key="row.day")
          span.metrics__heatmap-day {{ row.day }}
          .metrics__heatmap-cells
            span.metrics__heatmap-cell(
              v-for="cell in row.cells",
              :key="cell.hour",
              :data-tip="`${row.day} ${cell.label} · ${cell.count} ${cell.count === 1 ? 'view' : 'views'}`",
            )
              span.metrics__heatmap-fill(
                :class="{ hot: cell.level > 0 }",
                :style="cell.level > 0 ? { opacity: 0.3 + cell.level * 0.7 } : undefined",
              )
          span.metrics__heatmap-total {{ row.total || "" }}
        p.metrics__heatmap-caption last 7 days

    .metrics__week
      svg.metrics__week-svg(viewBox="0 0 700 80", preserveAspectRatio="none", aria-hidden="true")
        polygon.metrics__week-area(:points="weekLine.area")
        polyline.metrics__week-line(:points="weekLine.line")
      .metrics__week-axis
        span(v-for="(day, index) in weekDays", :key="index") {{ day }}
      p.metrics__week-caption hourly views · last 7 days

  section.note-target.metrics__section
    MarginNote(label="Pages")
    p.metrics__empty(v-if="!pages.length") no views recorded yet
    .metrics__areas(v-if="areas.length")
      .metrics__areas-bar
        .metrics__areas-seg(
          v-for="(area, index) in areas",
          :key="area.label",
          :style="{ width: `${area.share}%`, opacity: segOpacity(index) }",
          :title="`${area.label}: ${area.count}`",
        )
      ul.metrics__areas-legend
        li(v-for="(area, index) in areas", :key="area.label")
          span.metrics__areas-swatch(:style="{ opacity: segOpacity(index) }")
          | {{ area.label }}
          span.metrics__areas-count {{ area.count }}
    ul.metrics__rows(v-if="pages.length", :class="{ scrollable: allPages }")
      li.metrics__row(v-for="(page, index) in visiblePages", :key="page.path")
        .metrics__row-line
          span.metrics__rank {{ String(index + 1).padStart(2, "0") }}
          NuxtLink.metrics__row-link(:to="page.path") {{ page.path }}
          span.metrics__row-count {{ page.count }}
        .metrics__bar
          .metrics__bar-fill(:style="{ width: `${page.share}%` }")
    button.metrics__more(
      v-if="pages.length > 10",
      type="button",
      @click="allPages = !allPages",
    )
      | {{ allPages ? "collapse" : `see all (${pages.length})` }}
      span.metrics__more-arrow {{ allPages ? "↑" : "↓" }}

  section.note-target.metrics__section
    MarginNote(label="Places")
    MetricsWorldMap.metrics__map
    .metrics__grid
      .metrics__panel
        h2.metrics__panel-title top locations
        p.metrics__empty(v-if="!topLocations.length") no visitors logged yet
        ul.metrics__rows(v-else, :class="{ scrollable: allLocations }")
          li.metrics__row(v-for="(entry, index) in visibleLocations", :key="`${entry.city}|${entry.state}`")
            .metrics__row-line
              span.metrics__rank {{ String(index + 1).padStart(2, "0") }}
              span.metrics__row-label {{ entry.city }}, {{ entry.state }}
              span.metrics__row-count {{ entry.count }}
            .metrics__bar
              .metrics__bar-fill(:style="{ width: `${entry.share}%` }")
        button.metrics__more(
          v-if="topLocations.length > 10",
          type="button",
          @click="allLocations = !allLocations",
        )
          | {{ allLocations ? "collapse" : `see all (${topLocations.length})` }}
          span.metrics__more-arrow {{ allLocations ? "↑" : "↓" }}

      .metrics__panel
        h2.metrics__panel-title recent visitors
        p.metrics__empty(v-if="!recentVisitors.length") no visitors logged yet
        ul.metrics__rows(v-else)
          li.metrics__row(v-for="entry in recentVisitors", :key="`${entry.city}|${entry.state}`")
            .metrics__row-line.leader
              span.metrics__row-label {{ entry.city }}, {{ entry.state }}
              span.metrics__leader
              span.metrics__row-count {{ timeAgo(entry.last_visit_ms) }}

  section.note-target.metrics__section
    MarginNote(label="Live")
    .metrics__grid
      .metrics__panel
        h2.metrics__panel-title event feed
        p.metrics__empty(v-if="!metrics.events.length") waiting for events
        TransitionGroup.metrics__rows(v-else, tag="ul", name="feed")
          li.metrics__row(v-for="event in feed", :key="event.at + event.label")
            .metrics__row-line.leader
              span.metrics__feed-kind(:class="event.kind") {{ event.kind }}
              span.metrics__row-label {{ event.label }}
              span.metrics__leader
              span.metrics__row-count {{ feedAge(event.at) }}

      .metrics__panel
        h2.metrics__panel-title now
        ul.metrics__rows
          li.metrics__row(v-if="mounted && metrics.lastVisitor")
            .metrics__row-line.leader
              span.metrics__row-label previous visitor
              span.metrics__leader
              span.metrics__row-count {{ metrics.lastVisitor.city }}, {{ metrics.lastVisitor.state }}
          li.metrics__row(v-if="metrics.health")
            .metrics__row-line.leader
              span.metrics__row-label server time
              span.metrics__leader
              span.metrics__row-count {{ serverTime }}
          li.metrics__row
            .metrics__row-line.leader
              span.metrics__row-label last event
              span.metrics__leader
              span.metrics__row-count {{ lastEvent }}
        .metrics__clock
          svg(viewBox="0 0 220 220", role="img", aria-label="activity by hour of day")
            circle.metrics__clock-ring(cx="110", cy="110", r="40")
            circle.metrics__clock-ring(cx="110", cy="110", r="92")
            line.metrics__clock-bar(
              v-for="bar in clockBars",
              :key="bar.hour",
              :x1="bar.x1", :y1="bar.y1", :x2="bar.x2", :y2="bar.y2",
              :style="{ opacity: bar.opacity }",
            )
            line.metrics__clock-hand(
              :x1="clockNow.x1", :y1="clockNow.y1",
              :x2="clockNow.x2", :y2="clockNow.y2",
            )
            text.metrics__clock-label(
              v-for="label in clockLabels",
              :key="label.text",
              :x="label.x", :y="label.y",
            ) {{ label.text }}
          p.metrics__clock-caption activity by hour of day

  AppFooter.metrics__footer(v-if="profile", :profile)
</template>

<script lang="ts" setup>
/** ## metrics — live analytics over the shared backend: pulse, pages, places, feed. */
const metrics = useMetrics()

const { data: profile } = await useProfile()

useSeoMeta({
  title: "Metrics · Amittai Siavava",
  robots: "noindex, nofollow",
})

const clock = ref(Date.now())
const mounted = ref(false)

const ekg = ref<number[]>(Array.from({ length: 140 }, () => 0))

const ekgPoints = computed(() =>
  ekg.value
    .map((amplitude, i) => {
      const x = i / (ekg.value.length - 1) * 700
      return `${x.toFixed(1)},${(30 - amplitude * 24).toFixed(1)}`
    })
    .join(" "))

watch(() => metrics.lastEventAt, (at) => {
  if (!at || !mounted.value) return
  const trail = [...ekg.value]
  trail[trail.length - 1] = Math.min(1, (trail[trail.length - 1] ?? 0) + 1)
  ekg.value = trail
})

const eventsWithin = (ms: number) =>
  metrics.events.filter(event => clock.value - event.at < ms).length

const eventsLastHour = computed(() => eventsWithin(3600000))
const eventsLastFive = computed(() => eventsWithin(300000))

const hourBars = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const hours = Array.from({ length: 24 }, (_, i) => current - 23 + i)
  const max = Math.max(1, ...hours.map(h => metrics.activity[h] ?? 0))
  return hours.map(hour => ({
    hour,
    count: metrics.activity[hour] ?? 0,
    height: (metrics.activity[hour] ?? 0) === 0
      ? 0
      : Math.max(6, Math.round((metrics.activity[hour] ?? 0) / max * 100)),
    label: new Date(hour * 3600000).toLocaleTimeString([], { hour: "numeric" }),
    current: hour === current,
  }))
})

const hourTicks = computed(() =>
  [0, 6, 12, 18, 23].map(i => hourBars.value[i]?.label ?? ""))

const heatmap = computed(() => {
  const currentHour = Math.floor(clock.value / 3600000)
  const max = Math.max(1, ...Object.values(metrics.activity))
  const days = Array.from({ length: 7 }, (_, i) => 6 - i)
  return days.map((back) => {
    const dayStart = currentHour - currentHour % 24 - back * 24
    const date = new Date(dayStart * 3600000)
    const cells = Array.from({ length: 24 }, (_, hour) => {
      const count = metrics.activity[dayStart + hour] ?? 0
      return {
        hour,
        count,
        label: new Date((dayStart + hour) * 3600000)
          .toLocaleTimeString([], { hour: "numeric" }),
        level: count === 0 ? 0 : count / max,
      }
    })
    return {
      day: date.toLocaleDateString([], { weekday: "short" }).toLowerCase(),
      cells,
      total: cells.reduce((sum, cell) => sum + cell.count, 0),
    }
  })
})

const pulseCaption = computed(() => {
  const buckets = Object.entries(metrics.activity)
    .map(([hour, count]) => ({ hour: Number(hour), count }))
    .filter(bucket => bucket.count > 0)
  if (!buckets.length) return ""
  const peak = buckets.reduce((a, b) => b.count > a.count ? b : a)
  const peakLabel = new Date(peak.hour * 3600000)
    .toLocaleString([], { weekday: "short", hour: "numeric" })
    .toLowerCase()
  const busiest = heatmap.value.reduce((a, b) => b.total > a.total ? b : a)
  const weekTotal = heatmap.value.reduce((sum, row) => sum + row.total, 0)
  const average = Math.round(weekTotal / 7)
  return `peak ${peakLabel} (${peak.count}) · busiest ${busiest.day} (${busiest.total}) · avg ${average}/day`
})

const weekLine = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const hours = Array.from({ length: 168 }, (_, i) => current - 167 + i)
  const max = Math.max(1, ...hours.map(hour => metrics.activity[hour] ?? 0))
  const points = hours.map((hour, i) => {
    const x = i / 167 * 700
    const y = 76 - (metrics.activity[hour] ?? 0) / max * 68
    return `${x.toFixed(1)},${y.toFixed(1)}`
  })
  return {
    line: points.join(" "),
    area: `0,80 ${points.join(" ")} 700,80`,
  }
})

const weekDays = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  return Array.from({ length: 7 }, (_, i) =>
    new Date((current - (6 - i) * 24) * 3600000)
      .toLocaleDateString([], { weekday: "short" })
      .toLowerCase())
})

const clockBars = computed(() => {
  const byHour = Array.from({ length: 24 }, () => 0)
  for (const [hourTs, count] of Object.entries(metrics.activity)) {
    const hour = new Date(Number(hourTs) * 3600000).getHours()
    byHour[hour] = (byHour[hour] ?? 0) + count
  }
  const max = Math.max(1, ...byHour)
  const currentHour = new Date(clock.value).getHours()
  return byHour
    .map((count, hour) => {
      const angle = hour / 24 * Math.PI * 2 - Math.PI / 2
      const level = count / max
      const length = count === 0 ? 0 : 6 + level * 38
      return {
        hour,
        x1: 110 + Math.cos(angle) * 44,
        y1: 110 + Math.sin(angle) * 44,
        x2: 110 + Math.cos(angle) * (44 + length),
        y2: 110 + Math.sin(angle) * (44 + length),
        opacity: hour === currentHour ? 1 : 0.3 + level * 0.7,
        count,
      }
    })
    .filter(bar => bar.count > 0)
})

const clockNow = computed(() => {
  const now = new Date(clock.value)
  const angle
    = (now.getHours() + now.getMinutes() / 60) / 24 * Math.PI * 2 - Math.PI / 2
  return {
    x1: 110 + Math.cos(angle) * 28,
    y1: 110 + Math.sin(angle) * 28,
    x2: 110 + Math.cos(angle) * 38,
    y2: 110 + Math.sin(angle) * 38,
  }
})

const clockLabels = [
  { text: "00", x: 110, y: 12 },
  { text: "06", x: 209, y: 113 },
  { text: "12", x: 110, y: 216 },
  { text: "18", x: 11, y: 113 },
]

const shownViews = computed(() =>
  Object.entries(metrics.views)
    .filter(([path]) => path !== METRICS_DASHBOARD_PATH))

const pages = computed(() => {
  const entries = shownViews.value
    .map(([path, count]) => ({ path, count }))
    .sort((a, b) => b.count - a.count)
  const max = entries[0]?.count || 1
  return entries.map(entry => ({
    ...entry,
    share: Math.max(4, Math.round(entry.count / max * 100)),
  }))
})

const totalViews = computed(() =>
  shownViews.value.reduce((sum, [, count]) => sum + count, 0))

const areas = computed(() => {
  const totals: Record<string, number> = {}
  for (const [path, count] of shownViews.value) {
    const segments = path.split("/").filter(Boolean)
    const area = segments.length === 0
      ? "home"
      : segments[0] === "projects" && segments.length > 1
        ? segments[1]!
        : segments[0]!
    totals[area] = (totals[area] ?? 0) + count
  }
  const total = Object.values(totals).reduce((sum, count) => sum + count, 0) || 1
  const ranked = Object.entries(totals)
    .map(([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count)
  const top = ranked.slice(0, 7)
  const rest = ranked.slice(7).reduce((sum, area) => sum + area.count, 0)
  if (rest > 0) top.push({ label: "other", count: rest })
  return top.map(area => ({ ...area, share: area.count / total * 100 }))
})

const segOpacity = (index: number) => Math.max(0.18, 1 - index * 0.16)

const totalVisits = computed(() =>
  metrics.locationHistory.reduce((sum, entry) => sum + entry.count, 0))

const bumpViews = ref(false)
const bumpVisits = ref(false)

const flash = (flag: { value: boolean }) => {
  flag.value = true
  setTimeout(() => {
    flag.value = false
  }, 600)
}

watch(totalViews, (_, previous) => previous > 0 && flash(bumpViews))
watch(totalVisits, (_, previous) => previous > 0 && flash(bumpVisits))

const topLocations = computed(() => {
  const max = metrics.locationHistory[0]?.count || 1
  return metrics.locationHistory.map(entry => ({
    ...entry,
    share: Math.max(4, Math.round(entry.count / max * 100)),
  }))
})

const allPages = ref(false)
const allLocations = ref(false)

const visiblePages = computed(() =>
  allPages.value ? pages.value : pages.value.slice(0, 10))

const visibleLocations = computed(() =>
  allLocations.value ? topLocations.value : topLocations.value.slice(0, 10))

const recentVisitors = computed(() =>
  [...metrics.locationHistory]
    .sort((a, b) => b.last_visit_ms - a.last_visit_ms)
    .slice(0, 10))

const feed = computed(() => metrics.events.slice(0, 10))

const uptime = computed(() => {
  const elapsed = metrics.healthAt
    ? (clock.value - metrics.healthAt) / 1000
    : 0
  const secs = (metrics.health?.uptimeSecs ?? 0) + elapsed
  const days = Math.floor(secs / 86400)
  const hours = Math.floor(secs % 86400 / 3600)
  const minutes = Math.floor(secs % 3600 / 60)
  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${minutes}m`
  return `${minutes}m`
})

const serverTime = computed(() => {
  const time = metrics.health?.serverTime
  if (!time) return "—"
  const elapsed = metrics.healthAt ? clock.value - metrics.healthAt : 0
  return new Date(new Date(time).getTime() + elapsed).toLocaleTimeString([], {
    hour: "2-digit", minute: "2-digit", second: "2-digit",
  })
})

const lastEvent = computed(() => {
  if (!metrics.lastEventAt) return "—"
  return feedAge(metrics.lastEventAt)
})

const feedAge = (at: number) => {
  const secs = Math.floor((clock.value - at) / 1000)
  if (secs < 2) return "just now"
  if (secs < 60) return `${secs}s ago`
  return timeAgo(at)
}

const timeAgo = (ms: number) => {
  if (!ms) return "—"
  const delta = Date.now() - ms
  const minutes = Math.floor(delta / 60000)
  if (minutes < 1) return "just now"
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return new Date(ms).toLocaleDateString([], { month: "short", day: "numeric", year: "numeric" })
}

let ticker: ReturnType<typeof setInterval> | undefined

onMounted(() => {
  mounted.value = true
  metrics.dashboardActive = true
  metrics.seedDashboard()
  ticker = setInterval(() => {
    clock.value = Date.now()
    ekg.value = [...ekg.value.slice(1), 0]
  }, 1000)
})

onBeforeUnmount(() => {
  metrics.dashboardActive = false
  clearInterval(ticker)
})
</script>

<style lang="sass" scoped>
@use "@/styles/typography"

.metrics
  padding-top: 47px

  @media (max-width: 900px)
    padding-top: 24px

.metrics__head
  display: flex
  align-items: baseline
  justify-content: space-between
  gap: 16px
  flex-wrap: wrap

.metrics__title
  margin: 0
  font-size: typography.font-size("m")
  font-weight: 500
  color: var(--foreground-strong)

.metrics__status
  margin: 0
  font-size: typography.font-size("xxs")
  color: var(--foreground)

.metrics__dot
  position: relative
  display: inline-block
  width: 7px
  height: 7px
  margin-right: 0.55em
  border-radius: 50%
  background: var(--check-pending)

  &.live
    background: var(--check-done)

    &::after
      content: ""
      position: absolute
      inset: 0
      border-radius: 50%
      background: var(--check-done)
      animation: metrics-ping 2.4s ease-out infinite

      @media (prefers-reduced-motion: reduce)
        animation: none

@keyframes metrics-ping
  0%
    opacity: 0.6
    transform: scale(1)
  70%
    opacity: 0
    transform: scale(2.8)
  100%
    opacity: 0
    transform: scale(2.8)

.metrics__sep
  margin: 0 0.6em
  color: var(--note)

.metrics__ekg
  margin-top: 14px

  svg
    display: block
    width: 100%
    height: 36px

.metrics__ekg-base
  stroke: var(--grid)
  stroke-width: 1
  stroke-dasharray: 1 3
  vector-effect: non-scaling-stroke

.metrics__ekg-line
  fill: none
  stroke: var(--accent)
  stroke-width: 1.5
  vector-effect: non-scaling-stroke

.metrics__section
  position: relative
  margin-top: 52px

.metrics__footer
  margin-top: 64px

.metrics__pulse
  display: grid
  grid-template-columns: auto 1fr auto
  gap: 28px 36px
  align-items: end

  @media (max-width: 1000px)
    grid-template-columns: 1fr
    align-items: start

.metrics__counters
  display: grid
  gap: 14px

  @media (max-width: 1000px)
    grid-template-columns: repeat(2, minmax(120px, 1fr))

.metrics__counter-value
  margin: 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 1.35rem
  line-height: 1.1
  color: var(--foreground-strong)
  font-variant-numeric: tabular-nums
  transition: color 0.45s ease

  &.bump
    color: var(--accent)
    transition: color 0.1s ease

.metrics__counter-label
  margin: 2px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--foreground)

.metrics__chart
  align-self: stretch
  display: flex
  flex-direction: column
  justify-content: flex-end

.metrics__chart-bars
  display: flex
  align-items: flex-end
  gap: 3px
  height: 120px
  border-bottom: 1px dotted var(--grid)

.metrics__chart-col
  flex: 1
  display: flex
  align-items: flex-end
  height: 100%

.metrics__chart-fill
  width: 100%
  background: var(--accent)
  opacity: 0.55
  transition: height 0.4s ease

  &.current
    opacity: 1
    animation: chart-breathe 2.6s ease-in-out infinite

    @media (prefers-reduced-motion: reduce)
      animation: none

@keyframes chart-breathe
  0%, 100%
    opacity: 1
  50%
    opacity: 0.6

.metrics__chart-axis
  display: flex
  justify-content: space-between
  margin-top: 6px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.metrics__chart-caption
  margin: 4px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.metrics__heatmap
  display: grid
  gap: 3px

.metrics__heatmap-row
  display: flex
  align-items: center
  gap: 8px

.metrics__heatmap-day
  width: 26px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.metrics__heatmap-cells
  display: flex
  gap: 3px

.metrics__heatmap-cell
  position: relative
  width: 9px
  height: 9px
  background: #f0f0f1

  .dark-mode &
    background: var(--panel)

  &::after
    content: attr(data-tip)
    position: absolute
    bottom: calc(100% + 6px)
    left: 50%
    transform: translateX(-50%)
    padding: 3px 7px
    background: var(--foreground-strong)
    color: var(--background)
    font-family: typography.font("monospace"), ui-monospace, monospace
    font-size: typography.font-size("meta")
    white-space: nowrap
    opacity: 0
    pointer-events: none
    transition: opacity 0.15s ease

  &:hover
    z-index: 4

    &::after
      opacity: 1
      transition: opacity 0.15s ease 2s

.metrics__heatmap-fill
  position: absolute
  inset: 0

  &.hot
    background: var(--accent)

.metrics__heatmap-total
  min-width: 3ch
  text-align: right
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--foreground)
  font-variant-numeric: tabular-nums

.metrics__heatmap-caption
  margin: 6px 0 0 34px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.metrics__week
  margin-top: 28px

.metrics__week-svg
  display: block
  width: 100%
  height: 70px
  border-bottom: 1px dotted var(--grid)

.metrics__week-area
  fill: var(--accent)
  opacity: 0.07

.metrics__week-line
  fill: none
  stroke: var(--accent)
  stroke-width: 1.5
  vector-effect: non-scaling-stroke

.metrics__week-axis
  display: flex
  margin-top: 6px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

  span
    flex: 1

.metrics__week-caption
  margin: 4px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.metrics__clock
  margin-top: 22px

.metrics__clock svg
  display: block
  width: 200px

.metrics__clock-ring
  fill: none
  stroke: var(--grid)
  stroke-width: 1
  stroke-dasharray: 1 3
  stroke-linecap: round

.metrics__clock-bar
  stroke: var(--accent)
  stroke-width: 4

.metrics__clock-hand
  stroke: var(--foreground-strong)
  stroke-width: 1.5

.metrics__clock-label
  fill: var(--note)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 9px
  text-anchor: middle

.metrics__clock-caption
  margin: 8px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

.metrics__areas
  margin-bottom: 20px

.metrics__areas-bar
  display: flex
  height: 6px
  background-image: repeating-linear-gradient(90deg, var(--grid) 0 2px, transparent 2px 6px)

.metrics__areas-seg
  height: 100%
  background: var(--accent)
  transition: width 0.4s ease

.metrics__areas-legend
  margin: 8px 0 0
  padding: 0
  display: flex
  flex-wrap: wrap
  gap: 4px 18px
  list-style: none
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--foreground)

  li
    display: flex
    align-items: center
    gap: 6px

.metrics__areas-swatch
  width: 8px
  height: 8px
  background: var(--accent)

.metrics__areas-count
  color: var(--note)
  font-variant-numeric: tabular-nums

.metrics__map
  margin-bottom: 26px

.metrics__grid
  display: grid
  grid-template-columns: 1fr 1fr
  gap: 28px 36px

  @media (max-width: 900px)
    grid-template-columns: 1fr

.metrics__panel-title
  margin: 0 0 12px
  font-size: typography.font-size("xxs")
  font-weight: 500
  color: var(--foreground-strong)

.metrics__empty
  margin: 0
  font-size: typography.font-size("xxs")
  color: var(--note)

.metrics__rows
  margin: 0
  padding: 0
  display: flex
  flex-direction: column
  gap: 10px
  list-style: none

  &.scrollable
    max-height: 380px
    overflow-y: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none

.metrics__row-line
  display: flex
  align-items: baseline
  gap: 10px

.metrics__rank
  flex: none
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)
  font-variant-numeric: tabular-nums

.metrics__row-link
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("xs")
  color: var(--accent)
  text-decoration: none
  overflow-wrap: anywhere

  &:hover
    color: var(--foreground-strong)

.metrics__row-label
  font-size: typography.font-size("xs")
  color: var(--foreground)
  overflow-wrap: anywhere

.metrics__row-count
  margin-left: auto
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("xs")
  color: var(--foreground-strong)
  white-space: nowrap
  font-variant-numeric: tabular-nums

.metrics__feed-kind
  flex: none
  width: 6ch
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  text-transform: uppercase
  letter-spacing: 0.06em

  &.view
    color: var(--accent)

  &.visit
    color: var(--check-done)

.metrics__leader
  flex: 1
  min-width: 24px
  border-bottom: 1px dotted var(--divider)
  transform: translateY(-3px)

.metrics__row-line.leader .metrics__row-count
  margin-left: 0

.metrics__bar
  margin: 4px 0 0 calc(0.6rem + 10px)
  height: 4px
  background-image: repeating-linear-gradient(90deg, var(--grid) 0 2px, transparent 2px 6px)

.metrics__bar-fill
  height: 100%
  background-image: repeating-linear-gradient(90deg, var(--accent) 0 2px, transparent 2px 6px)
  transition: width 0.4s ease

.metrics__more
  margin-top: 14px
  padding: 0
  background: none
  border: none
  font-family: inherit
  font-size: typography.font-size("xs")
  color: var(--accent)
  cursor: pointer

.metrics__more-arrow
  display: inline-block
  margin-left: 0.3em
  transition: transform 0.18s cubic-bezier(0.22, 0.61, 0.36, 1)

  @media (prefers-reduced-motion: reduce)
    transition: none

.metrics__more:hover .metrics__more-arrow
  transform: translateY(2px)

.feed-enter-active,
.feed-move
  transition: opacity 0.35s ease, transform 0.35s ease

  @media (prefers-reduced-motion: reduce)
    transition: none

.feed-enter-from
  opacity: 0
  transform: translateY(-6px)

.feed-leave-active
  display: none
</style>
