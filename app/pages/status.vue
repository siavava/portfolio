<template lang="pug">
main.metrics(:class="`skin-${skin}`")
  NameBar(v-if="profile", :profile)
  header.metrics__head
    h1.metrics__title Status
    .metrics__sites
      button.metrics__site(
        v-for="option in siteOptions",
        :key="option.id",
        type="button",
        :class="{ active: site === option.id }",
        @click="site = option.id",
      ) {{ option.label }}
    p.metrics__status
      span.metrics__dot(:class="{ live: mounted && metrics.connected }")
      | {{ mounted && metrics.connected ? "live" : "connecting" }}
      span.metrics__sep |
      | {{ mounted ? metrics.activeCount : 0 }} online
      template(v-if="metrics.health")
        span.metrics__sep |
        | up {{ uptime }}

  .metrics__ekg(aria-hidden="true")
    svg(viewBox="0 0 700 36", preserveAspectRatio="none")
      line.metrics__ekg-base(x1="0", y1="30", x2="700", y2="30")
      polyline.metrics__ekg-line(:points="ekgPoints")

  .dash-canvas
    .metrics__tiles
      .metrics__counter
        p.metrics__counter-value(:class="{ bump: bumpViews }") {{ totalViews }}
        p.metrics__counter-label page views
        p.metrics__counter-delta(v-if="weekDelta", :class="{ up: weekDelta.up }")
          | {{ weekDelta.up ? "+" : "" }}{{ weekDelta.pct }}% vs last week
      .metrics__counter
        p.metrics__counter-value(:class="{ bump: bumpVisits }") {{ totalVisits }}
        p.metrics__counter-label visits logged
      .metrics__counter
        p.metrics__counter-value {{ viewsPerVisit }}
        p.metrics__counter-label views / visit
      .metrics__counter
        p.metrics__counter-value {{ eventsLastHour }}
        p.metrics__counter-label events / 1 hour
      .metrics__counter
        p.metrics__counter-value {{ eventsLastFive }}
        p.metrics__counter-label events / 5 min
      .metrics__counter
        p.metrics__counter-value {{ peakHourLabel }}
        p.metrics__counter-label peak hour · 7 days
      .metrics__counter
        p.metrics__counter-value {{ streak }}d
        p.metrics__counter-label day streak
      .metrics__counter
        p.metrics__counter-value {{ avgPerDay }}
        p.metrics__counter-label avg views / day

    .dash
      .dash-panel.dash--map
        span.dash-legend places
        .metrics__reach
          .metrics__reach-item
            p.metrics__reach-value {{ reach.cities }}
            p.metrics__reach-label {{ reach.cities === 1 ? "city" : "cities" }}
          .metrics__reach-item
            p.metrics__reach-value {{ reach.regions }}
            p.metrics__reach-label {{ reach.regions === 1 ? "region" : "regions" }}
          .metrics__reach-item
            p.metrics__reach-value {{ totalVisits }}
            p.metrics__reach-label visits
          .metrics__reach-item
            p.metrics__reach-value {{ placedViews }}
            p.metrics__reach-label placed views
          .metrics__reach-item
            p.metrics__reach-value {{ reach.latest }}
            p.metrics__reach-label last visit
        MetricsWorldMap.metrics__map(:entries="mergedLocations")

      .dash-panel.dash--feed
        span.dash-legend event feed
        p.metrics__empty(v-if="!metrics.events.length") waiting for events
        .metrics__scroll(v-else, ref="feedBox")
          TransitionGroup.metrics__rows(tag="ul", name="feed")
            li.metrics__row(v-for="event in feed", :key="event.id")
              .metrics__row-line.leader
                span.metrics__feed-kind(:class="event.kind") {{ event.kind }}
                span.metrics__site-tag(v-if="site === 'all'") {{ event.tag }}
                span.metrics__row-label {{ event.label }}
                span.metrics__row-place(
                  v-if="event.place && event.kind !== 'visit'",
                ) {{ event.place }}
                span.metrics__leader
                span.metrics__row-count {{ feedAge(event.at) }}
          .metrics__scroll-fade.top(:class="{ visible: feedFades.up.value }")
          .metrics__scroll-fade.bottom(:class="{ visible: feedFades.down.value }")

      .dash-panel.dash--ticks
        span.dash-legend views by site
        .metrics__ticks
          .metrics__ticks-seg(
            v-for="split in siteTicks",
            :key="split.ns",
            :style="{ flexGrow: split.width }",
          )
            .metrics__ticks-head
              span.metrics__ticks-label {{ split.label }}
              span.metrics__ticks-count {{ split.total }}
            .metrics__ticks-bar

      .dash-panel.dash--hours
        span.dash-legend views by hour · 24h
        .metrics__chart
          .metrics__chart-bars
            .metrics__chart-col(
              v-for="bar in hourBars",
              :key="bar.hour",
              :data-tip="`${bar.label} · ${bar.count} ${bar.count === 1 ? 'view' : 'views'}`",
            )
              .metrics__chart-fill(
                :class="{ current: bar.current, zero: bar.count === 0 }",
                :style="{ height: `${bar.height}%` }",
              )
          .metrics__chart-axis
            span(v-for="tick in hourTicks", :key="tick") {{ tick }}
          p.metrics__chart-caption(v-if="pulseCaption") {{ pulseCaption }}

      .dash-panel.dash--heat
        span.dash-legend last 7 days
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

      .dash-panel.dash--clock
        span.dash-legend activity clock
        .metrics__clock
          .metrics__clock-box
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
            span.metrics__clock-hot(
              v-for="bar in clockBars",
              :key="`hot-${bar.hour}`",
              :style="{ left: `${bar.hotX}%`, top: `${bar.hotY}%` }",
              :data-tip="`${String(bar.hour).padStart(2, '0')}:00 · ${bar.count} ${bar.count === 1 ? 'view' : 'views'}`",
            )

      .dash-panel.dash--pages
        span.dash-legend pages
        p.metrics__empty(v-if="!pages.length") no views recorded yet
        .metrics__areas(v-if="areas.length")
          .metrics__areas-bar
            .metrics__areas-seg(
              v-for="(area, index) in areas",
              :key="area.label",
              :style="{ width: `${area.share}%` }",
              :data-tip="`${area.label} · ${area.count} ${area.count === 1 ? 'view' : 'views'}`",
            )
              .metrics__areas-fill(:style="{ background: `var(--dash-c${index % 5})` }")
          ul.metrics__areas-legend
            li(v-for="(area, index) in areas", :key="area.label")
              span.metrics__areas-swatch(:style="{ background: `var(--dash-c${index % 5})` }")
              | {{ area.label }}
              span.metrics__areas-count {{ area.count }}
        .metrics__scroll(v-if="pages.length", ref="pagesBox")
          ul.metrics__rows.metrics__rows--pages(:class="{ scrollable: allPages }")
            li.metrics__row(v-for="(page, index) in visiblePages", :key="page.ns + page.path")
              .metrics__row-line
                span.metrics__rank {{ String(index + 1).padStart(2, "0") }}
                span.metrics__site-tag(v-if="site === 'all'") {{ page.tag }}
                NuxtLink.metrics__row-link(v-if="page.linkable", :to="page.path") {{ page.path }}
                a.metrics__row-link(
                  v-else-if="page.href",
                  :href="page.href",
                  target="_blank",
                  rel="noopener",
                ) {{ page.path }}
                span.metrics__row-label(v-else) {{ page.path }}
                span.metrics__row-count {{ page.count }}
              .metrics__bar
                .metrics__bar-fill(:style="{ width: `${page.share}%` }")
          .metrics__scroll-fade.top(:class="{ visible: allPages && pagesFades.up.value }")
          .metrics__scroll-fade.bottom(:class="{ visible: allPages && pagesFades.down.value }")
        button.metrics__more(
          v-if="pages.length > 10",
          type="button",
          @click="allPages = !allPages",
        )
          | {{ allPages ? "collapse" : `see all (${pages.length})` }}
          span.metrics__more-arrow {{ allPages ? "↑" : "↓" }}

      .dash-panel.dash--locations
        span.dash-legend top locations
        p.metrics__empty(v-if="!topLocations.length") no visitors logged yet
        .metrics__scroll(v-else, ref="locationsBox")
          ul.metrics__rows(:class="{ scrollable: allLocations }")
            li.metrics__row(v-for="(entry, index) in visibleLocations", :key="`${entry.city}|${entry.state}`")
              .metrics__row-line
                span.metrics__rank {{ String(index + 1).padStart(2, "0") }}
                span.metrics__row-label {{ entry.city }}, {{ entry.state }}
                span.metrics__row-count {{ entry.count }}
              .metrics__bar
                .metrics__bar-fill(:style="{ width: `${entry.share}%` }")
          .metrics__scroll-fade.top(:class="{ visible: allLocations && locationsFades.up.value }")
          .metrics__scroll-fade.bottom(:class="{ visible: allLocations && locationsFades.down.value }")
        button.metrics__more(
          v-if="topLocations.length > 10",
          type="button",
          @click="allLocations = !allLocations",
        )
          | {{ allLocations ? "collapse" : `see all (${topLocations.length})` }}
          span.metrics__more-arrow {{ allLocations ? "↑" : "↓" }}

      .dash-panel.dash--visitors
        span.dash-legend visitors · now
        ul.metrics__rows
          li.metrics__row(v-for="entry in recentVisitors.slice(0, 6)", :key="`${entry.city}|${entry.state}`")
            .metrics__row-line.leader
              span.metrics__row-label {{ entry.city }}, {{ entry.state }}
              span.metrics__leader
              span.metrics__row-count {{ timeAgo(entry.last_visit_ms) }}
        ul.metrics__rows.metrics__rows--now
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

      .dash-panel.dash--gauge
        span.dash-legend today
        .metrics__gauge
          svg(viewBox="0 0 160 160", role="img", aria-label="views today versus the busiest day")
            circle.metrics__gauge-track(cx="80", cy="80", r="64")
            circle.metrics__gauge-arc(
              cx="80", cy="80", r="64",
              transform="rotate(-90 80 80)",
              :style="{ strokeDasharray: todayGauge.dash }",
            )
            text.metrics__gauge-num(x="80", y="78") {{ todayGauge.today }}
            text.metrics__gauge-sub(x="80", y="98") views today
          p.metrics__gauge-caption {{ Math.round(todayGauge.pct * 100) }}% of busiest day

      .dash-panel.dash--compass
        span.dash-legend visitor bearing
        p.metrics__empty(v-if="!compass") no located visitors yet
        .metrics__gauge(v-else)
          svg(viewBox="0 0 160 160", role="img", aria-label="bearing to the latest visitor")
            circle.metrics__gauge-track(cx="80", cy="80", r="64")
            text.metrics__compass-cardinal(x="80", y="12") N
            text.metrics__compass-cardinal(x="152", y="84") E
            text.metrics__compass-cardinal(x="80", y="156") S
            text.metrics__compass-cardinal(x="8", y="84") W
            line.metrics__compass-needle(
              :x1="compass.tailX", :y1="compass.tailY",
              :x2="compass.tipX", :y2="compass.tipY",
            )
            circle.metrics__compass-pivot(cx="80", cy="80", r="3")
          p.metrics__gauge-caption {{ compass.city }} · {{ compass.km.toLocaleString() }} km {{ compass.cardinal }}

      .dash-panel.dash--coverage
        span.dash-legend coverage
        .metrics__matrix
          span.metrics__matrix-dot(
            v-for="cell in coverageHours",
            :key="cell.hour",
            :class="{ on: cell.count > 0 }",
            :data-tip="cell.tip",
          )
        p.metrics__gauge-caption {{ coverage.active }} / 168 hrs with traffic

      .dash-panel.dash--days
        span.dash-legend views / day
        .metrics__days
          .metrics__days-bars
            .metrics__day(
              v-for="bar in dayBars",
              :key="bar.day",
              :data-tip="`${bar.day} · ${bar.count} ${bar.count === 1 ? 'view' : 'views'}`",
            )
              .metrics__day-fill(:style="{ height: `${bar.height}%` }")
          .metrics__days-axis
            span(v-for="bar in dayBars", :key="bar.day") {{ bar.day.slice(0, 1) }}

      .dash-panel.dash--week
        span.dash-legend hourly views · last 7 days
        .metrics__week
          svg.metrics__week-svg(viewBox="0 0 700 80", preserveAspectRatio="none", aria-hidden="true")
            polygon.metrics__week-area(:points="weekLine.area")
            polyline.metrics__week-line(:points="weekLine.line")
          .metrics__week-hover
            span(v-for="cell in weekHours", :key="cell.hour", :data-tip="cell.tip")
          .metrics__week-axis
            span(v-for="(day, index) in weekDays", :key="index") {{ day }}

  AppFooter.metrics__footer(v-if="profile", :profile)

  aside.metrics__aside(v-if="profile")
    NuxtLink.metrics__aside-name(to="/") {{ profile.name }}
    p.metrics__aside-place {{ profile.location }}
    p.metrics__aside-label site
    span.metrics__aside-row.active status
    a.metrics__aside-row(href="/sitemap.xml", target="_blank", rel="noopener") sitemap
    NuxtLink.metrics__aside-row(to="/") {{ profile.site }}
    p.metrics__aside-label appearance
    button.metrics__aside-row(type="button", @click="toggleColor")
      | {{ mounted && isDark ? "light" : "dark" }} mode
    p.metrics__aside-label versions · {{ profile.version }}
    a.metrics__aside-row(
      v-for="past in profile.versions",
      :key="past.label",
      :href="past.url",
      target="_blank",
      rel="noopener",
    )
      span {{ past.label }}
      span.metrics__aside-dim {{ past.url.replace("https://", "") }}

</template>

<script lang="ts" setup>
import { useScroll } from "@vueuse/core"

/** ## status — live analytics for every tracked site: pulse, pages, places, feed. */
const metrics = useMetrics()

const { data: profile } = await useProfile()

useSeoMeta({
  title: "Status · Amittai Siavava",
  robots: "noindex, nofollow",
})

const clock = ref(Date.now())
const { isDark, toggle: toggleColor } = useColorToggle()

const mounted = ref(false)

const SKINS = ["instrument", "mercury"] as const
type Skin = (typeof SKINS)[number]

const querySkin = useRoute().query.skin
const skin = ref<Skin>(
  SKINS.includes(querySkin as Skin) ? querySkin as Skin : "instrument",
)

const site = ref<SiteId | "all">("<p>")

const siteOptions: { id: SiteId | "all", label: string }[] = [
  ...SITE_IDS.map(id => ({ id, label: SITE_META[id].label })),
  { id: "all" as const, label: "all" },
]

const selectedSites = computed<SiteId[]>(() =>
  site.value === "all" ? SITE_IDS : [site.value])

const mergedActivity = computed<Record<number, number>>(() => {
  const merged: Record<number, number> = {}
  for (const ns of selectedSites.value) {
    for (const [hour, count] of Object.entries(metrics.activity[ns])) {
      merged[Number(hour)] = (merged[Number(hour)] ?? 0) + count
    }
  }
  return merged
})

const selectedEvents = computed(() =>
  [...metrics.events]
    .filter(event => selectedSites.value.includes(event.ns))
    .sort((a, b) => b.at - a.at))

const mergedLocations = computed<LocationHistoryEntry[]>(() => {
  const merged = new Map<string, LocationHistoryEntry>()
  const fold = (entry: LocationHistoryEntry) => {
    const key = `${entry.city}|${entry.state}`
    const existing = merged.get(key)
    if (!existing) {
      merged.set(key, { ...entry })
      return
    }
    existing.count += entry.count
    existing.last_visit_ms
      = Math.max(existing.last_visit_ms, entry.last_visit_ms)
    existing.lat = existing.lat ?? entry.lat
    existing.lon = existing.lon ?? entry.lon
  }
  for (const ns of selectedSites.value) {
    for (const entry of metrics.locationHistory[ns]) fold(entry)
    // Attributed views weigh into the same map/reach pool as visits.
    for (const entry of metrics.viewLocations[ns]) {
      fold({
        city: entry.city,
        state: entry.state,
        count: entry.count,
        last_visit_ms: entry.last_view_ms,
        lat: entry.lat,
        lon: entry.lon,
      })
    }
  }
  return [...merged.values()].sort((a, b) => b.count - a.count)
})

const placedViews = computed(() =>
  selectedSites.value.reduce((sum, ns) =>
    sum + metrics.viewLocations[ns].reduce(
      (siteSum, entry) => siteSum + entry.count, 0,
    ), 0))

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
  selectedEvents.value.filter(event => clock.value - event.at < ms).length

const eventsLastHour = computed(() => eventsWithin(3600000))
const eventsLastFive = computed(() => eventsWithin(300000))

const hourBars = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const hours = Array.from({ length: 24 }, (_, i) => current - 23 + i)
  const activity = mergedActivity.value
  const max = Math.max(1, ...hours.map(h => activity[h] ?? 0))
  return hours.map(hour => ({
    hour,
    count: activity[hour] ?? 0,
    height: (activity[hour] ?? 0) === 0
      ? 0
      : Math.max(6, Math.round((activity[hour] ?? 0) / max * 100)),
    label: new Date(hour * 3600000).toLocaleTimeString([], { hour: "numeric" }),
    current: hour === current,
  }))
})

const hourTicks = computed(() =>
  [0, 6, 12, 18, 23].map(i => hourBars.value[i]?.label ?? ""))

const heatmap = computed(() => {
  const currentHour = Math.floor(clock.value / 3600000)
  const activity = mergedActivity.value
  const max = Math.max(1, ...Object.values(activity))
  const days = Array.from({ length: 7 }, (_, i) => 6 - i)
  return days.map((back) => {
    const dayStart = currentHour - currentHour % 24 - back * 24
    const date = new Date(dayStart * 3600000)
    const cells = Array.from({ length: 24 }, (_, hour) => {
      const count = activity[dayStart + hour] ?? 0
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

const weekBuckets = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  return Object.entries(mergedActivity.value)
    .map(([hour, count]) => ({ hour: Number(hour), count }))
    .filter(bucket => bucket.count > 0 && bucket.hour > current - 168)
})

const pulseCaption = computed(() => {
  const buckets = weekBuckets.value
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

const avgPerDay = computed(() => {
  const weekTotal = heatmap.value.reduce((sum, row) => sum + row.total, 0)
  return Math.round(weekTotal / 7)
})

const peakHourLabel = computed(() => {
  const buckets = weekBuckets.value
  if (!buckets.length) return "—"
  const peak = buckets.reduce((a, b) => b.count > a.count ? b : a)
  return new Date(peak.hour * 3600000)
    .toLocaleTimeString([], { hour: "numeric" })
    .toLowerCase()
    .replace(/\s/, " ")
})

const weekDelta = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  let thisWeek = 0
  let lastWeek = 0
  for (const [hour, count] of Object.entries(mergedActivity.value)) {
    const h = Number(hour)
    if (h > current - 168) thisWeek += count
    else if (h > current - 336) lastWeek += count
  }
  if (!lastWeek) return null
  const pct = Math.round((thisWeek - lastWeek) / lastWeek * 100)
  return { pct, up: pct >= 0 }
})

const dayBars = computed(() => {
  const rows = heatmap.value
  const max = Math.max(1, ...rows.map(row => row.total))
  return rows.map(row => ({
    day: row.day,
    count: row.total,
    height: row.total === 0 ? 0 : Math.max(6, Math.round(row.total / max * 100)),
  }))
})

const weekLine = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const hours = Array.from({ length: 168 }, (_, i) => current - 167 + i)
  const activity = mergedActivity.value
  const max = Math.max(1, ...hours.map(hour => activity[hour] ?? 0))
  const points = hours.map((hour, i) => {
    const x = i / 167 * 700
    const y = 76 - (activity[hour] ?? 0) / max * 68
    return `${x.toFixed(1)},${y.toFixed(1)}`
  })
  return {
    line: points.join(" "),
    area: `0,80 ${points.join(" ")} 700,80`,
  }
})

const weekHours = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const activity = mergedActivity.value
  return Array.from({ length: 168 }, (_, i) => {
    const hour = current - 167 + i
    const date = new Date(hour * 3600000)
    const count = activity[hour] ?? 0
    const day = date.toLocaleDateString([], { weekday: "short" }).toLowerCase()
    const label = `${day} ${String(date.getHours()).padStart(2, "0")}:00`
    return { hour, tip: `${label} · ${count} ${count === 1 ? "view" : "views"}` }
  })
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
  for (const bucket of weekBuckets.value) {
    const hour = new Date(bucket.hour * 3600000).getHours()
    byHour[hour] = (byHour[hour] ?? 0) + bucket.count
  }
  const max = Math.max(1, ...byHour)
  const currentHour = new Date(clock.value).getHours()
  return byHour
    .map((count, hour) => {
      const angle = hour / 24 * Math.PI * 2 - Math.PI / 2
      const level = count / max
      const length = count === 0 ? 0 : 6 + level * 38
      const midRadius = 44 + length / 2
      return {
        hour,
        x1: 110 + Math.cos(angle) * 44,
        y1: 110 + Math.sin(angle) * 44,
        x2: 110 + Math.cos(angle) * (44 + length),
        y2: 110 + Math.sin(angle) * (44 + length),
        hotX: (110 + Math.cos(angle) * midRadius) / 220 * 100,
        hotY: (110 + Math.sin(angle) * midRadius) / 220 * 100,
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
    .map(([route, count]) => ({ route, count, ns: siteOf(route) }))
    .filter((entry): entry is { route: string, count: number, ns: SiteId } =>
      entry.ns !== null
      && selectedSites.value.includes(entry.ns)
      && entry.route !== withSite("<p>", METRICS_DASHBOARD_PATH)))

const routePatterns = useRouter().getRoutes().map((record) => {
  const pattern = record.path
    .replace(/\/:[^/]+\(\.\*\)\*$/, "(?:/.*)?")
    .replace(/:[^/]+/g, "[^/]+")
  return new RegExp(`^${pattern}/?$`)
})

const isRealRoute = (path: string) =>
  routePatterns.some(pattern => pattern.test(path))

const pages = computed(() => {
  const entries = shownViews.value
    .map(({ route, count, ns }) => ({ ns, path: stripSite(route), count }))
    .sort((a, b) => b.count - a.count)
  const max = entries[0]?.count || 1
  return entries.map((entry) => {
    const origin = SITE_META[entry.ns].origin
    return {
      ...entry,
      tag: SITE_META[entry.ns].tag,
      share: Math.max(4, Math.round(entry.count / max * 100)),
      linkable: origin === null && isRealRoute(entry.path),
      href: origin ? `${origin}${entry.path}` : null,
    }
  })
})

const totalViews = computed(() =>
  shownViews.value.reduce((sum, { count }) => sum + count, 0))

const areas = computed(() => {
  const totals: Record<string, number> = {}
  for (const { route, count } of shownViews.value) {
    const segments = stripSite(route).split("/").filter(Boolean)
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

const totalVisits = computed(() =>
  mergedLocations.value.reduce((sum, entry) => sum + entry.count, 0))

const viewsPerVisit = computed(() => {
  if (!totalVisits.value) return "—"
  return (totalViews.value / totalVisits.value).toFixed(1)
})

const todayGauge = computed(() => {
  const rows = dayBars.value
  const today = rows[rows.length - 1]?.count ?? 0
  const busiest = Math.max(1, ...rows.map(row => row.count))
  const pct = Math.min(1, today / busiest)
  const circumference = 2 * Math.PI * 64
  return {
    today,
    pct,
    dash: `${(circumference * pct).toFixed(1)} ${circumference.toFixed(1)}`,
  }
})

const HOME = { lat: 37.4529, lon: -122.1817 }

const compass = computed(() => {
  const located = [...mergedLocations.value]
    .filter(entry => entry.lat != null && entry.lon != null)
    .sort((a, b) => b.last_visit_ms - a.last_visit_ms)
  const target = located[0]
  if (!target) return null
  const lat = target.lat ?? 0
  const lon = target.lon ?? 0
  const toRad = (deg: number) => deg * Math.PI / 180
  const phi1 = toRad(HOME.lat)
  const phi2 = toRad(lat)
  const dLon = toRad(lon - HOME.lon)
  const y = Math.sin(dLon) * Math.cos(phi2)
  const x = Math.cos(phi1) * Math.sin(phi2)
    - Math.sin(phi1) * Math.cos(phi2) * Math.cos(dLon)
  const bearing = (Math.atan2(y, x) * 180 / Math.PI + 360) % 360
  const dPhi = toRad(lat - HOME.lat)
  const half = Math.sin(dPhi / 2) ** 2
    + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dLon / 2) ** 2
  const km = Math.round(2 * 6371 * Math.asin(Math.sqrt(half)))
  const winds = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
  const rad = toRad(bearing)
  return {
    city: target.city,
    km,
    cardinal: winds[Math.round(bearing / 45) % 8],
    tipX: 80 + Math.sin(rad) * 52,
    tipY: 80 - Math.cos(rad) * 52,
    tailX: 80 - Math.sin(rad) * 14,
    tailY: 80 + Math.cos(rad) * 14,
  }
})

const coverage = computed(() => ({ active: weekBuckets.value.length }))

const coverageHours = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const activity = mergedActivity.value
  return Array.from({ length: 168 }, (_, i) => {
    const hour = current - 167 + i
    const date = new Date(hour * 3600000)
    const count = activity[hour] ?? 0
    const day = date.toLocaleDateString([], { weekday: "short" }).toLowerCase()
    const label = `${day} ${String(date.getHours()).padStart(2, "0")}:00`
    return { hour, count, tip: `${label} · ${count} ${count === 1 ? "view" : "views"}` }
  })
})

const streak = computed(() => {
  const current = Math.floor(clock.value / 3600000)
  const dayStart = current - current % 24
  let days = 0
  for (let back = 0; back < 14; back++) {
    const start = dayStart - back * 24
    let total = 0
    for (let h = 0; h < 24; h++) total += mergedActivity.value[start + h] ?? 0
    if (total > 0) days++
    else break
  }
  return days
})

const reach = computed(() => {
  const entries = mergedLocations.value
  const regions = new Set(entries.map(entry => entry.state)).size
  const latestAt = Math.max(0, ...entries.map(entry => entry.last_visit_ms))
  return {
    cities: entries.length,
    regions,
    latest: latestAt ? timeAgo(latestAt) : "—",
  }
})

const siteTicks = computed(() => {
  const total = siteSplit.value.reduce((sum, split) => sum + split.total, 0)
  if (!total) return []
  return siteSplit.value
    .filter(split => split.total > 0)
    .map(split => ({
      ...split,
      width: Math.max(8, split.total / total * 100),
    }))
})

const siteSplit = computed(() => {
  const totals = SITE_IDS.map((ns) => {
    const total = Object.entries(metrics.views)
      .filter(([route]) =>
        siteOf(route) === ns
        && route !== withSite("<p>", METRICS_DASHBOARD_PATH))
      .reduce((sum, [, count]) => sum + count, 0)
    return { ns, label: SITE_META[ns].label, total }
  })
  const grand = totals.reduce((sum, entry) => sum + entry.total, 0) || 1
  return totals.map(entry => ({
    ...entry,
    share: Math.round(entry.total / grand * 100),
  }))
})

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
  const max = mergedLocations.value[0]?.count || 1
  return mergedLocations.value.map(entry => ({
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
  [...mergedLocations.value]
    .sort((a, b) => b.last_visit_ms - a.last_visit_ms)
    .slice(0, 10))

const feed = computed(() => selectedEvents.value.slice(0, 300).map(event => ({
  ...event,
  tag: SITE_META[event.ns].tag,
})))

const pagesBox = useTemplateRef<HTMLElement>("pagesBox")
const locationsBox = useTemplateRef<HTMLElement>("locationsBox")
const feedBox = useTemplateRef<HTMLElement>("feedBox")

const edgeFades = (box: { value: HTMLElement | null }) => {
  const list = computed(() => box.value?.querySelector("ul") ?? null)
  const { arrivedState } = useScroll(list, { offset: { top: 2, bottom: 2 } })
  return {
    up: computed(() => !arrivedState.top),
    down: computed(() => !arrivedState.bottom),
    measure: () => list.value?.dispatchEvent(new Event("scroll")),
  }
}

const pagesFades = edgeFades(pagesBox)
const locationsFades = edgeFades(locationsBox)
const feedFades = edgeFades(feedBox)

watch([allPages, () => visiblePages.value.length], () =>
  nextTick(pagesFades.measure))
watch([allLocations, () => visibleLocations.value.length], () =>
  nextTick(locationsFades.measure))
watch(() => feed.value.length, () =>
  nextTick(feedFades.measure))

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
  --dash-canvas: #e8eaee
  --dash-card: #ffffff
  --dash-card-2: #eceef2
  --dash-track: #eceef2
  --dash-ink: #1d1f24
  --dash-on-ink: rgba(255, 255, 255, 0.62)
  --dash-text: rgba(29, 31, 36, 0.6)
  --dash-faint: rgba(29, 31, 36, 0.38)
  --dash-line: rgba(29, 31, 36, 0.07)
  --dash-stem: rgba(29, 31, 36, 0.22)
  --dash-primary: #ff4800
  --dash-second: #7f9bc7
  --dash-green: #3d9c74
  --dash-warm: #b7bcc6
  --dash-shadow: 0 1px 2px rgba(29, 31, 36, 0.03), 0 14px 36px -20px rgba(29, 31, 36, 0.14)
  --dash-c0: var(--dash-ink)
  --dash-c1: var(--dash-primary)
  --dash-c2: var(--dash-second)
  --dash-c3: var(--dash-warm)
  --dash-c4: var(--dash-green)

  .dark-mode &
    --dash-canvas: #17181c
    --dash-card: #1f2126
    --dash-card-2: #2a2d33
    --dash-track: #2b2e34
    --dash-ink: #f2f3f5
    --dash-on-ink: rgba(29, 31, 36, 0.62)
    --dash-text: rgba(242, 243, 245, 0.6)
    --dash-faint: rgba(242, 243, 245, 0.36)
    --dash-line: rgba(242, 243, 245, 0.06)
    --dash-stem: rgba(242, 243, 245, 0.24)
    --dash-primary: #ff6a3d
    --dash-second: #8ba6d8
    --dash-green: #37b686
    --dash-warm: #70747d
    --dash-shadow: none

  padding-top: 47px

  @media (max-width: 900px)
    padding-top: 0

  @media (min-width: 1280px)
    width: min(1660px, calc(100vw - 128px))
    margin-left: calc((100% - min(1660px, calc(100vw - 128px))) / 2)

.metrics__head
  display: flex
  align-items: baseline
  justify-content: space-between
  gap: 16px
  flex-wrap: wrap
  margin-top: 24px

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

.metrics__sites
  display: inline-flex
  align-self: center
  gap: 2px
  padding: 4px
  background: var(--dash-card-2)
  border-radius: 999px

.metrics__site
  padding: 5px 16px
  background: none
  border: none
  border-radius: 999px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.04em
  color: var(--dash-text)
  cursor: pointer
  transition: color 0.15s ease, background 0.15s ease

  &:hover
    color: var(--dash-ink)

  &.active
    background: var(--dash-ink)
    color: var(--dash-card)

.metrics__site-tag
  flex: none
  width: 1ch
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-faint)

.metrics__ekg
  margin-top: 14px

  svg
    display: block
    width: 100%
    height: 36px

.metrics__ekg-base
  stroke: var(--dash-line)
  stroke-width: 1
  stroke-dasharray: 1 3
  vector-effect: non-scaling-stroke

.metrics__ekg-line
  fill: none
  stroke: var(--dash-primary)
  stroke-width: 1.5
  vector-effect: non-scaling-stroke

.metrics__aside
  display: none

.metrics__footer
  margin-top: 64px

.dash-canvas
  margin-top: 30px
  padding: 26px
  border-radius: 30px
  background: var(--dash-canvas)

  @media (max-width: 700px)
    padding: 14px
    border-radius: 22px

.dash
  display: grid
  grid-template-columns: repeat(12, 1fr)
  gap: 24px

.dash-panel
  grid-column: span 12
  position: relative
  min-width: 0
  background: var(--dash-card)
  border: 1px solid var(--dash-line)
  border-radius: 22px
  box-shadow: var(--dash-shadow)
  padding: 20px 24px 22px

.dash-legend
  display: block
  margin: 0 0 18px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.08em
  color: var(--dash-faint)
  white-space: nowrap

@media (min-width: 900px) and (max-width: 1279px)
  .dash--hours, .dash--heat, .dash--clock, .dash--days,
  .dash--locations, .dash--visitors,
  .dash--gauge, .dash--compass, .dash--coverage
    grid-column: span 6

@media (min-width: 1280px)
  .dash--map
    grid-column: span 8

  .dash--feed
    grid-column: span 4

  .dash--ticks
    grid-column: span 12

  .dash--hours
    grid-column: span 5

  .dash--heat
    grid-column: span 4

  .dash--clock
    grid-column: span 3

  .dash--pages
    grid-column: span 6

  .dash--locations
    grid-column: span 3

  .dash--visitors
    grid-column: span 3

  .dash--week
    grid-column: span 12

  .dash--days, .dash--gauge, .dash--compass, .dash--coverage
    grid-column: span 3

  .dash--pages .metrics__rows
    display: grid
    grid-template-columns: repeat(2, minmax(0, 1fr))
    gap: 10px 56px
    align-content: start

.dash--heat .metrics__heatmap-cells
  flex: 1

.dash--clock .metrics__clock
  margin-top: 6px

  svg
    margin: 0 auto

.metrics__rows--now
  margin-top: 18px
  padding-top: 16px
  border-top: 1px solid var(--dash-line)

.metrics__reach
  display: flex
  flex-wrap: wrap
  gap: 12px 44px
  margin-bottom: 20px

.metrics__reach-value
  margin: 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 1.05rem
  color: var(--dash-ink)
  font-variant-numeric: tabular-nums
  white-space: nowrap

.metrics__reach-label
  margin: 2px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--dash-faint)

.metrics__ticks
  display: flex
  gap: 22px

  @media (max-width: 700px)
    flex-direction: column

.metrics__ticks-seg
  --seg: var(--dash-primary)
  flex: 0 1 auto
  min-width: 0
  border-left: 1px solid var(--dash-line)
  padding-left: 14px

  &:nth-child(2)
    --seg: var(--dash-ink)

  &:nth-child(3)
    --seg: var(--dash-second)

  .metrics__ticks-head
    white-space: nowrap

.metrics__ticks-head
  display: flex
  align-items: baseline
  gap: 10px
  margin-bottom: 10px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--dash-text)

.metrics__ticks-count
  font-size: typography.font-size("xs")
  color: var(--dash-ink)
  font-variant-numeric: tabular-nums

.metrics__ticks-bar
  height: 34px
  border-radius: 4px
  background-image: repeating-linear-gradient(90deg, var(--seg) 0 2px, transparent 2px 7px)

.metrics__gauge
  svg
    display: block
    width: 156px
    margin: 4px auto 0

.metrics__map :deep(.world__dot)
  fill: var(--dash-faint)
  opacity: 0.5

.metrics__map :deep(.world__marker)
  fill: var(--dash-primary)

.metrics__map :deep(.world__site:hover .world__marker)
  fill: var(--dash-ink)

.metrics__map :deep(.world__ping)
  stroke: var(--dash-primary)

.metrics__map :deep(.world__tip)
  background: var(--dash-ink)
  color: var(--dash-card)

.metrics__gauge-track
  fill: none
  stroke: var(--dash-faint)
  stroke-width: 1
  stroke-dasharray: 1 4
  stroke-linecap: round

.metrics__gauge-arc
  fill: none
  stroke: var(--dash-primary)
  stroke-width: 6
  stroke-linecap: round
  transition: stroke-dasharray 0.5s ease

.metrics__gauge-num
  fill: var(--dash-ink)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 26px
  text-anchor: middle
  font-variant-numeric: tabular-nums

.metrics__gauge-sub
  fill: var(--dash-faint)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 9px
  letter-spacing: 0.06em
  text-anchor: middle

.metrics__gauge-caption
  margin: 10px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-faint)
  text-align: center

.metrics__compass-cardinal
  fill: var(--dash-faint)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 9px
  text-anchor: middle

.metrics__compass-needle
  stroke: var(--dash-primary)
  stroke-width: 2.5
  stroke-linecap: round

.metrics__compass-pivot
  fill: var(--dash-ink)

.metrics__matrix
  display: grid
  grid-template-columns: repeat(21, 10px)
  gap: 5px
  justify-content: center
  margin-top: 12px

.metrics__matrix-dot
  @extend %metrics-tip
  width: 10px
  height: 10px
  border-radius: 3px
  background: var(--dash-track)

  &.on
    background: var(--dash-green)

.metrics__tiles
  display: grid
  grid-template-columns: repeat(2, minmax(0, 1fr))
  gap: 14px
  margin-bottom: 24px

  @media (min-width: 900px)
    grid-template-columns: repeat(4, minmax(0, 1fr))

  @media (min-width: 1500px)
    grid-template-columns: repeat(8, minmax(0, 1fr))

.metrics__tiles .metrics__counter
  min-width: 0
  background: var(--dash-card)
  border: 1px solid var(--dash-line)
  border-radius: 18px
  box-shadow: var(--dash-shadow)
  padding: 16px 18px

  &:first-child
    background: var(--dash-ink)
    border-color: var(--dash-ink)

    .metrics__counter-value
      color: var(--dash-card)

    .metrics__counter-label
      color: var(--dash-on-ink)

    .metrics__counter-delta
      color: var(--dash-primary)

      &.up
        color: var(--dash-green)

.metrics__counter-value
  margin: 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 1.5rem
  line-height: 1.1
  color: var(--dash-ink)
  font-variant-numeric: tabular-nums
  transition: color 0.45s ease

  &.bump
    color: var(--accent)
    transition: color 0.1s ease

.metrics__counter-label
  margin: 5px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  letter-spacing: 0.06em
  color: var(--dash-faint)

.metrics__counter-delta
  margin: 6px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-primary)

  &.up
    color: var(--dash-green)

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
  border-bottom: 1px solid var(--dash-line)

.metrics__chart-col
  @extend %metrics-tip
  flex: 1
  display: flex
  align-items: flex-end
  height: 100%

.metrics__chart-fill
  position: relative
  width: 2px
  margin: 0 auto
  background: var(--dash-stem)
  transition: height 0.4s ease

  &::after
    content: ""
    position: absolute
    top: -3px
    left: 50%
    transform: translateX(-50%)
    width: 7px
    height: 7px
    border-radius: 50%
    background: var(--dash-second)

  &.zero::after
    display: none

  &.current
    background: var(--dash-primary)
    animation: chart-breathe 2.6s ease-in-out infinite

    &::after
      background: var(--dash-primary)

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
  color: var(--dash-faint)

.metrics__chart-caption
  margin: 8px 0 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-faint)

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
  color: var(--dash-faint)

.metrics__heatmap-cells
  display: flex
  gap: 3px
  flex: 1
  min-width: 0

%metrics-tip
  position: relative

  &::after
    content: attr(data-tip)
    display: none
    position: absolute
    bottom: calc(100% + 6px)
    left: 50%
    transform: translateX(-50%)
    padding: 4px 8px
    background: var(--dash-ink)
    color: var(--dash-card)
    font-family: typography.font("monospace"), ui-monospace, monospace
    font-size: typography.font-size("meta")
    white-space: nowrap
    pointer-events: none

  &:hover
    z-index: 4

    &::after
      display: block

.metrics__heatmap-cell
  @extend %metrics-tip
  flex: 1 1 0
  max-width: 10px
  min-width: 0
  height: 10px
  border-radius: 3px
  background: var(--dash-track)

.metrics__heatmap-fill
  position: absolute
  inset: 0
  border-radius: 3px

  &.hot
    background: var(--dash-primary)

.metrics__heatmap-total
  min-width: 3ch
  text-align: right
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-text)
  font-variant-numeric: tabular-nums

.metrics__days
  align-self: stretch
  display: flex
  flex-direction: column
  justify-content: flex-end

.metrics__days-bars
  display: flex
  align-items: flex-end
  gap: 6px
  height: 96px
  border-bottom: 1px solid var(--dash-line)

.metrics__day
  @extend %metrics-tip
  flex: 1 1 0
  max-width: 26px
  display: flex
  align-items: flex-end
  height: 100%

.metrics__day-fill
  width: 100%
  background: var(--dash-ink)
  opacity: 0.82
  border-radius: 4px
  transition: height 0.4s ease

.metrics__day:last-child .metrics__day-fill
  background: var(--dash-primary)
  opacity: 1

.metrics__days-axis
  display: flex
  gap: 6px
  margin-top: 6px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--note)

  span
    flex: 1 1 0
    max-width: 26px
    text-align: center
    color: var(--dash-faint)

.metrics__week
  position: relative
  margin-top: 28px

.metrics__week-hover
  position: absolute
  top: 0
  left: 0
  right: 0
  height: 70px
  display: flex

  span
    @extend %metrics-tip
    flex: 1

.metrics__week-svg
  display: block
  width: 100%
  height: 70px
  border-bottom: 1px solid var(--dash-line)

.metrics__week-area
  fill: var(--dash-second)
  opacity: 0.1

.metrics__week-line
  fill: none
  stroke: var(--dash-second)
  stroke-width: 1.5
  vector-effect: non-scaling-stroke

.metrics__week-axis
  display: flex
  margin-top: 6px
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-faint)

  span
    flex: 1

.metrics__clock
  margin-top: 22px

.metrics__clock-box
  position: relative
  width: 200px
  margin: 0 auto

.metrics__clock-hot
  @extend %metrics-tip
  position: absolute
  width: 22px
  height: 22px
  translate: -50% -50%
  border-radius: 50%

.metrics__clock svg
  display: block
  width: 200px

.metrics__clock-ring
  fill: none
  stroke: var(--dash-faint)
  stroke-width: 1
  stroke-dasharray: 1 3
  stroke-linecap: round

.metrics__clock-bar
  stroke: var(--dash-primary)
  stroke-width: 4
  stroke-linecap: round

.metrics__clock-hand
  stroke: var(--dash-ink)
  stroke-width: 1.5

.metrics__clock-label
  fill: var(--dash-faint)
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: 9px
  text-anchor: middle

.metrics__areas
  margin-bottom: 20px

.metrics__areas-bar
  display: flex
  gap: 3px
  height: 8px

.metrics__areas-seg
  @extend %metrics-tip
  height: 100%
  transition: width 0.4s ease

.metrics__areas-fill
  height: 100%
  border-radius: 4px

.metrics__areas-legend
  margin: 10px 0 0
  padding: 0
  display: flex
  flex-wrap: wrap
  gap: 4px 18px
  list-style: none
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-text)

  li
    display: flex
    align-items: center
    gap: 6px

.metrics__areas-swatch
  width: 8px
  height: 8px
  border-radius: 3px

.metrics__areas-count
  color: var(--dash-faint)
  font-variant-numeric: tabular-nums

.metrics__empty
  margin: 0
  font-size: typography.font-size("xxs")
  color: var(--dash-faint)

.metrics__scroll
  position: relative

.dash--feed
  display: flex
  flex-direction: column
  min-height: 440px

  .metrics__scroll
    flex: 1
    min-height: 0

  .metrics__rows
    position: absolute
    inset: 0
    overflow-y: auto
    scrollbar-width: none

    &::-webkit-scrollbar
      display: none

.metrics__scroll-fade
  position: absolute
  left: 0
  right: 0
  height: 40px
  pointer-events: none
  opacity: 0
  transition: opacity 0.25s ease

  &.visible
    opacity: 1

  &.top
    top: 0
    background: linear-gradient(to bottom, var(--dash-card), transparent)

  &.bottom
    bottom: 0
    background: linear-gradient(to top, var(--dash-card), transparent)

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
  color: var(--dash-faint)
  font-variant-numeric: tabular-nums

.metrics__row-link
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("xs")
  color: var(--dash-ink)
  text-decoration: none
  min-width: 0
  white-space: nowrap
  overflow: hidden
  text-overflow: ellipsis

  &:hover
    color: var(--dash-primary)

.metrics__row-label
  font-size: typography.font-size("xs")
  color: var(--dash-text)
  min-width: 0
  white-space: nowrap
  overflow: hidden
  text-overflow: ellipsis

.metrics__row-place
  flex-shrink: 0
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("meta")
  color: var(--dash-faint)
  white-space: nowrap

.metrics__row-count
  margin-left: auto
  font-family: typography.font("monospace"), ui-monospace, monospace
  font-size: typography.font-size("xs")
  color: var(--dash-ink)
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
    color: var(--dash-primary)

  &.visit
    color: var(--dash-green)

.metrics__leader
  flex: 1
  min-width: 24px
  border-bottom: 1px dotted var(--dash-line)
  transform: translateY(-3px)

.metrics__row-line.leader .metrics__row-count
  margin-left: 0

.metrics__bar
  margin: 5px 0 0 calc(0.6rem + 10px)
  height: 4px
  border-radius: 2px
  background: var(--dash-track)

.metrics__bar-fill
  height: 100%
  border-radius: 2px
  background: var(--dash-second)
  transition: width 0.4s ease

.metrics__more
  margin-top: 14px
  padding: 0
  background: none
  border: none
  font-family: inherit
  font-size: typography.font-size("xs")
  color: var(--dash-second)
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

// ── skin prototypes ──────────────────────────────────────────────

// skin — mercury: ethereal void, floating modules, humanist sans, ghost title
.skin-mercury
  --dash-card: #fbfbfc
  --dash-card-2: rgba(74, 74, 96, 0.09)
  --dash-track: rgba(74, 74, 96, 0.1)
  --dash-ink: #2c2c30
  --dash-on-ink: rgba(255, 255, 255, 0.65)
  --dash-text: rgba(44, 44, 48, 0.62)
  --dash-faint: rgba(44, 44, 48, 0.4)
  --dash-line: rgba(44, 44, 48, 0.07)
  --dash-primary: #7c8499
  --dash-second: #a8a8b2
  --dash-green: #7d7d86
  --dash-warm: #bfbfc6
  --dash-shadow: 0 24px 60px -28px rgba(60, 60, 90, 0.28)
  --dash-mercury-sans: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", "Segoe UI", sans-serif

  .dark-mode &
    --dash-card: #232329
    --dash-card-2: rgba(236, 236, 239, 0.09)
    --dash-track: rgba(236, 236, 239, 0.1)
    --dash-ink: #ececef
    --dash-on-ink: rgba(35, 35, 39, 0.65)
    --dash-text: rgba(236, 236, 239, 0.6)
    --dash-faint: rgba(236, 236, 239, 0.38)
    --dash-line: rgba(236, 236, 239, 0.06)
    --dash-primary: #a4abbe
    --dash-second: #84848e
    --dash-green: #9a9aa2
    --dash-warm: #6e6e76
    --dash-shadow: 0 30px 70px -30px rgba(0, 0, 0, 0.55)

  &::before
    content: ""
    position: fixed
    inset: 0
    z-index: -1
    background: radial-gradient(74% 44% at 50% 6%, rgba(255, 255, 255, 0.5), transparent 62%), radial-gradient(90% 70% at 78% -10%, #d0ced7, transparent 62%), radial-gradient(80% 62% at -6% 34%, #cbccd5, transparent 60%), linear-gradient(170deg, #c0c0c6 0%, #cbcbd0 48%, #d4d4d1 100%)

  .dark-mode &::before
    background: radial-gradient(70% 42% at 50% 10%, rgba(255, 255, 255, 0.085), transparent 64%), radial-gradient(50% 34% at 24% 58%, rgba(255, 255, 255, 0.035), transparent 70%), linear-gradient(170deg, #1d1d1f 0%, #212123 48%, #202022 100%)

  .metrics__head
    position: relative
    z-index: 0
    min-height: 108px
    align-items: flex-end

  .metrics__title
    position: absolute
    top: -18px
    left: -4px
    margin: 0
    font-family: var(--dash-mercury-sans)
    font-size: clamp(4rem, 10vw, 9rem)
    font-weight: 600
    letter-spacing: -0.02em
    line-height: 1
    color: rgba(255, 255, 255, 0.55)
    pointer-events: none
    white-space: nowrap

    .dark-mode &
      color: rgba(255, 255, 255, 0.06)

  .metrics__sites,
  .metrics__status
    position: relative
    z-index: 1

  .dash-legend,
  .metrics__counter-value,
  .metrics__counter-label,
  .metrics__counter-delta,
  .metrics__reach-value,
  .metrics__reach-label,
  .metrics__row-count,
  .metrics__row-link,
  .metrics__rank,
  .metrics__chart-axis,
  .metrics__chart-caption,
  .metrics__heatmap-day,
  .metrics__heatmap-total,
  .metrics__days-axis,
  .metrics__week-axis,
  .metrics__gauge-caption,
  .metrics__ticks-head,
  .metrics__ticks-count,
  .metrics__areas-legend,
  .metrics__feed-kind,
  .metrics__site-tag,
  .metrics__site,
  .metrics__more,
  .metrics__empty
    font-family: var(--dash-mercury-sans)

  .metrics__gauge-num,
  .metrics__gauge-sub,
  .metrics__compass-cardinal,
  .metrics__clock-label
    font-family: var(--dash-mercury-sans)

  .metrics__feed-kind
    text-transform: none
    letter-spacing: 0

  .name-bar,
  .metrics__footer
    display: none

  .dash-canvas
    background: transparent
    padding: 0
    border-radius: 0
    max-width: 1160px
    margin-inline: auto

    @media (min-width: 1360px)
      margin-left: max(272px, calc((100% - 1160px) / 2))

  .metrics__aside
    display: flex
    flex-direction: column
    z-index: 6
    width: 216px
    padding: 18px 16px 14px
    border: 1px solid transparent
    border-radius: 18px
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.68), rgba(255, 255, 255, 0.48) 42%, rgba(255, 255, 255, 0.38))
    backdrop-filter: blur(30px) saturate(1.1)
    box-shadow: 0 24px 60px -30px rgba(50, 50, 62, 0.4)

    .dark-mode &
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.085), rgba(255, 255, 255, 0.045) 42%, rgba(255, 255, 255, 0.026))
      box-shadow: 0 20px 50px -32px rgba(0, 0, 0, 0.45)

    @media (max-width: 1359px)
      margin: 44px auto 0
      border-color: rgba(255, 255, 255, 0.6)

      .dark-mode &
        border-color: rgba(255, 255, 255, 0.08)

    @media (min-width: 1360px)
      position: fixed
      left: 26px
      top: 50%
      translate: 0 -50%
      border-color: transparent
      background: transparent
      backdrop-filter: none
      box-shadow: none
      opacity: 0.5

      .dark-mode &:not(:hover):not(:focus-within)
        border-color: transparent
        background: transparent
        backdrop-filter: none
        box-shadow: none
      transition: opacity 0.3s ease, background 0.3s ease, border-color 0.3s ease, box-shadow 0.3s ease

      &:hover,
      &:focus-within
        opacity: 1
        border-color: rgba(255, 255, 255, 0.6)
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.68), rgba(255, 255, 255, 0.48) 42%, rgba(255, 255, 255, 0.38))
        backdrop-filter: blur(30px) saturate(1.1)
        box-shadow: 0 24px 60px -30px rgba(50, 50, 62, 0.4)

      .dark-mode &:hover,
      .dark-mode &:focus-within
        border-color: rgba(255, 255, 255, 0.08)
        background: linear-gradient(180deg, rgba(255, 255, 255, 0.085), rgba(255, 255, 255, 0.045) 42%, rgba(255, 255, 255, 0.026))
        box-shadow: 0 20px 50px -32px rgba(0, 0, 0, 0.45)

  .metrics__aside-name
    font-family: var(--dash-mercury-sans)
    font-size: 0.84rem
    font-weight: 600
    color: var(--dash-ink)

    &:hover
      text-decoration: none

  .metrics__aside-place
    margin: 2px 0 0
    font-family: var(--dash-mercury-sans)
    font-size: 0.62rem
    color: var(--dash-faint)

  .metrics__aside-label
    margin: 15px 0 4px
    font-family: var(--dash-mercury-sans)
    font-size: 0.56rem
    letter-spacing: 0.14em
    text-transform: uppercase
    color: var(--dash-faint)

  .metrics__aside-row
    display: flex
    align-items: baseline
    justify-content: space-between
    gap: 8px
    margin: 0 -8px
    padding: 6px 8px
    border: 0
    border-radius: 9px
    background: transparent
    font-family: var(--dash-mercury-sans)
    font-size: 0.72rem
    color: var(--dash-text)
    text-align: left
    cursor: pointer
    transition: background 0.15s ease, color 0.15s ease

    &:hover
      background: rgba(255, 255, 255, 0.55)
      color: var(--dash-ink)
      text-decoration: none

      .dark-mode &
        background: rgba(255, 255, 255, 0.09)

    &.active
      background: rgba(255, 255, 255, 0.6)
      color: var(--dash-ink)
      cursor: default

      .dark-mode &
        background: rgba(255, 255, 255, 0.11)

  .metrics__aside-dim
    font-size: 0.6rem
    color: var(--dash-faint)

  .dash
    gap: 44px 40px
    margin-top: 34px

  .metrics__tiles
    display: flex
    flex-wrap: wrap
    justify-content: center
    gap: 14px
    margin: 4px auto 10px
    max-width: 1200px

  .metrics__tiles .metrics__counter
    flex: 0 0 auto
    min-width: 150px
    border: 0
    border-radius: 16px
    padding: 14px 20px 15px
    border: 1px solid rgba(255, 255, 255, 0.55)
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.6), rgba(255, 255, 255, 0.38))
    backdrop-filter: blur(22px) saturate(1.1)
    box-shadow: 0 14px 34px -22px rgba(50, 50, 62, 0.38)

    .dark-mode &
      border-color: rgba(255, 255, 255, 0.07)
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.075), rgba(255, 255, 255, 0.032))
      box-shadow: 0 14px 36px -26px rgba(0, 0, 0, 0.42)

    &:first-child
      background: var(--dash-card)
      border-color: transparent

      .dark-mode &
        background: rgba(255, 255, 255, 0.13)

      .metrics__counter-value
        color: var(--dash-ink)

      .metrics__counter-label
        color: var(--dash-faint)

      .metrics__counter-delta
        color: var(--dash-green)

  .metrics__counter-value
    font-weight: 300
    font-size: 1.7rem
    letter-spacing: -0.01em

  .dash-panel
    border: 1px solid rgba(255, 255, 255, 0.6)
    border-radius: 18px
    padding: 0 24px 22px
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.68), rgba(255, 255, 255, 0.48) 42%, rgba(255, 255, 255, 0.38))
    backdrop-filter: blur(30px) saturate(1.1)
    box-shadow: 0 24px 60px -30px rgba(50, 50, 62, 0.4)

    .dark-mode &
      border-color: rgba(255, 255, 255, 0.08)
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.085), rgba(255, 255, 255, 0.045) 42%, rgba(255, 255, 255, 0.026))
      box-shadow: 0 20px 50px -32px rgba(0, 0, 0, 0.45)

  .dash--feed
    height: 560px

  .dash-legend
    display: block
    flex: none
    margin: 0 -24px 20px
    padding: 13px 20px 12px
    border-bottom: 0
    border-radius: 17px 17px 0 0
    background: color-mix(in srgb, var(--dash-ink) 5%, transparent)
    font-size: 12px
    font-weight: 500
    letter-spacing: 0
    text-transform: none
    color: color-mix(in srgb, var(--dash-ink) 78%, transparent)

  .metrics__sites
    border: 1px solid rgba(255, 255, 255, 0.5)
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.55), rgba(255, 255, 255, 0.35))
    backdrop-filter: blur(16px)
    box-shadow: var(--dash-shadow)

    .dark-mode &
      border-color: rgba(255, 255, 255, 0.07)
      background: linear-gradient(180deg, rgba(255, 255, 255, 0.07), rgba(255, 255, 255, 0.035))

  .metrics__site
    font-size: 11px
    text-transform: none

  .metrics__dot.live
    background: var(--dash-primary)

    &::after
      background: var(--dash-primary)

  .metrics__more
    display: inline-block
    margin-top: 16px
    padding: 8px 16px
    border-radius: 999px
    background: color-mix(in srgb, var(--dash-ink) 6%, transparent)
    color: var(--dash-text)
    font-size: 12px

    &:hover
      color: var(--dash-ink)

  .metrics__chart-fill
    width: 100%
    margin: 0
    border-radius: 7px
    background: color-mix(in srgb, var(--dash-primary) 32%, var(--dash-card-2))

    &::after
      display: none

    &.current
      background: var(--dash-primary)

  .metrics__chart-bars
    gap: 5px
    border-bottom: 0

  .metrics__day-fill
    border-radius: 7px
    background: color-mix(in srgb, var(--dash-primary) 32%, var(--dash-card-2))
    opacity: 1

  .metrics__day:last-child .metrics__day-fill
    background: var(--dash-primary)

  .metrics__days-bars
    border-bottom: 0

  .metrics__week-svg
    border-bottom: 0

  .metrics__week-area
    opacity: 0.12

  .metrics__matrix-dot
    border-radius: 50%

    &.on
      background: var(--dash-primary)

  .metrics__gauge-track
    stroke-dasharray: 1 6

  [data-tip]::after
    border-radius: 8px
    font-family: var(--dash-mercury-sans)

// skin — instrument: blueprint lattice, two-tone + LED, graph paper
.skin-instrument
  --dash-second: #9aa0ab
  --dash-green: #2ecc5b
  --dash-warm: rgba(29, 31, 36, 0.35)
  --dash-rule: rgba(29, 31, 36, 0.24)
  --dash-paper: rgba(29, 31, 36, 0.06)

  .dark-mode &
    --dash-second: #7c828e
    --dash-warm: rgba(242, 243, 245, 0.35)
    --dash-rule: rgba(242, 243, 245, 0.24)
    --dash-paper: rgba(242, 243, 245, 0.07)

  .dash-canvas
    background: transparent
    padding: 0
    border-radius: 0

  .metrics__tiles
    gap: 0
    border: 1px solid var(--dash-rule)
    border-right: 0
    border-bottom: 0
    margin-bottom: -1px

  .metrics__tiles .metrics__counter
    position: relative
    background: transparent
    border: 0
    border-right: 1px solid var(--dash-rule)
    border-bottom: 1px solid var(--dash-rule)
    border-radius: 0
    box-shadow: none
    padding: 18px 20px

    &:first-child
      background: transparent
      border-color: var(--dash-rule)

      .metrics__counter-value
        color: var(--dash-ink)

      .metrics__counter-label
        color: var(--dash-faint)

  .metrics__counter-value
    font-size: 1.9rem

  .dash
    position: relative
    gap: 0
    border: 1px solid var(--dash-rule)
    border-right: 0
    border-bottom: 0
    background-image: radial-gradient(var(--dash-paper) 1px, transparent 1px)
    background-size: 16px 16px

  .metrics__tiles
    position: relative

  .dash-panel::before,
  .dash-panel::after,
  .metrics__tiles .metrics__counter::before,
  .metrics__tiles .metrics__counter::after,
  .dash::before,
  .dash::after,
  .metrics__tiles::before,
  .metrics__tiles::after
    content: ""
    position: absolute
    width: 9px
    height: 9px
    translate: -50% -50%
    z-index: 1
    pointer-events: none
    background: linear-gradient(var(--dash-ink), var(--dash-ink)) center / 1px 9px no-repeat, linear-gradient(var(--dash-ink), var(--dash-ink)) center / 9px 1px no-repeat

  .dash-panel::before,
  .metrics__tiles .metrics__counter::before
    left: -0.5px
    top: -0.5px

  .dash-panel::after,
  .metrics__tiles .metrics__counter::after
    left: calc(100% + 0.5px)
    top: calc(100% + 0.5px)

  .dash::before,
  .metrics__tiles::before
    left: calc(100% - 0.5px)
    top: -0.5px

  .dash::after,
  .metrics__tiles::after
    left: -0.5px
    top: calc(100% - 0.5px)

  .dash-panel
    background: transparent
    border: 0
    border-right: 1px solid var(--dash-rule)
    border-bottom: 1px solid var(--dash-rule)
    border-radius: 0
    box-shadow: none
    padding: 22px 24px

  .dash-legend
    letter-spacing: 0.16em
    text-transform: uppercase
    font-size: 0.55rem

  .metrics__tiles .metrics__counter:first-child .metrics__counter-value
    color: var(--dash-primary)

  .metrics__chart-fill
    width: 1px
    background: var(--dash-stem)

    &::after
      width: 5px
      height: 5px
      border-radius: 0
      background: var(--dash-ink)

    &.current::after
      background: var(--dash-primary)

  .metrics__heatmap-cell,
  .metrics__heatmap-fill,
  .metrics__matrix-dot,
  .metrics__day-fill,
  .metrics__areas-fill,
  .metrics__areas-swatch,
  .metrics__bar,
  .metrics__bar-fill,
  .metrics__ticks-bar
    border-radius: 0

  .metrics__day-fill
    background: var(--dash-ink)

  .metrics__week-area
    opacity: 0

  .metrics__week-line
    stroke: var(--dash-ink)

  .metrics__bar-fill
    background: var(--dash-ink)

  .metrics__sites
    background: transparent
    padding: 0
    gap: 16px

  .metrics__site
    padding: 2px 0
    border-radius: 0

    &.active
      background: transparent
      color: var(--dash-primary)

  .metrics__scroll-fade
    &.top
      background: linear-gradient(to bottom, var(--background), transparent)

    &.bottom
      background: linear-gradient(to top, var(--background), transparent)

</style>
