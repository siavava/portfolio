import { queryCollection } from "@nuxt/content/server"

import { sitemapXml } from "#purs/App.Server.Sitemap"

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
 * then by year (descending). The
 * URL assembly, sorting, and XML
 * serialization live in the
 * PureScript core
 * (`app/server/Sitemap.purs`); this
 * shell runs the content query and
 * sets the response header.
 *
 * ### Response
 *
 * `string` — XML sitemap with
 * `application/xml` content-type,
 * styled by `/sitemap.xsl`.
 */
export default defineEventHandler(async (event) => {
  const docs = await queryCollection(event, "projects")
    .select("path", "date", "featured")
    .all()

  setResponseHeader(event, "Content-Type", "application/xml; charset=utf-8")
  return sitemapXml({
    docs: docs.map(doc => ({
      path: doc.path,
      date: String(doc.date),
      featured: Boolean(doc.featured),
    })),
    thisYear: new Date().getFullYear(),
  })
})
