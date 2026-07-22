import { SitemapStream, streamToPromise } from "sitemap"

import { queryCollection } from "@nuxt/content/server"

const SITE_DOMAIN = "https://amittai.studio"

/**
 * ## GET `/sitemap.xml`
 *
 * Generates an XML sitemap from the
 * projects collection, plus the two
 * static routes. Assigns priority
 * by kind:
 *
 * | Route | Priority |
 * | --- | --- |
 * | `/` | `1.0` |
 * | `/projects` | `0.8` |
 * | featured project | `0.7` |
 * | project | `0.5` |
 *
 * Entries are sorted by priority,
 * then by year (descending).
 *
 * ### Response
 *
 * `Buffer` — XML sitemap with
 * `application/xml` content-type,
 * styled by `/sitemap.xsl`.
 */
export default defineEventHandler(async (event) => {
  const docs = await queryCollection(event, "projects")
    .select("path", "date", "featured")
    .all()

  const thisYear = new Date().getFullYear()

  const entries = [
    { url: "/", changefreq: "monthly", priority: 1.0, year: thisYear },
    { url: "/projects", changefreq: "monthly", priority: 0.8, year: thisYear },
    ...docs.map(doc => ({
      url: doc.path,
      changefreq: "monthly",
      priority: doc.featured ? 0.7 : 0.5,
      year: Number(String(doc.date).slice(0, 4)) || thisYear,
    })),
  ]

  entries.sort((a, b) =>
    b.priority - a.priority || Number(b.year) - Number(a.year))

  const sitemap = new SitemapStream({
    hostname: SITE_DOMAIN,
    xslUrl: `${SITE_DOMAIN}/sitemap.xsl`,
  })

  entries.forEach(({ url, changefreq, priority }) =>
    sitemap.write({ url, changefreq, priority }))
  sitemap.end()

  setResponseHeader(event, "Content-Type", "application/xml; charset=utf-8")
  return streamToPromise(sitemap)
})
