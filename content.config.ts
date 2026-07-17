import { defineCollection, defineContentConfig, z } from "@nuxt/content"

export default defineContentConfig({
  collections: {
    who: defineCollection({
      type: "page",
      source: { include: "who.md" },
      schema: z.object({
        title: z.string(),
      }),
    }),
    now: defineCollection({
      type: "page",
      source: { include: "now/**" },
      schema: z.object({
        title: z.string(),
        icon: z.string(),
        url: z.string(),
        interest: z.string().optional(),
      }),
    }),
    reviews: defineCollection({
      type: "page",
      source: { include: "reviews/**" },
      schema: z.object({
        author: z.string(),
        role: z.string(),
      }),
    }),
    dreams: defineCollection({
      type: "data",
      source: { include: "dreams.yml" },
      schema: z.object({
        items: z.array(z.object({
          label: z.string(),
          done: z.boolean().default(false),
        })),
      }),
    }),
    interests: defineCollection({
      type: "data",
      source: { include: "interests.yml" },
      schema: z.object({
        branches: z.array(z.object({
          label: z.string(),
          color: z.string(),
          children: z.array(z.object({
            label: z.string(),
            requires: z.array(z.string()).optional(),
            children: z.array(z.object({
              label: z.string(),
              requires: z.array(z.string()).optional(),
              children: z.array(z.object({
                label: z.string(),
                requires: z.array(z.string()).optional(),
              })).optional(),
            })).optional(),
          })),
        })),
      }),
    }),
    projects: defineCollection({
      type: "data",
      source: { include: "projects.yml" },
      schema: z.object({
        items: z.array(z.object({
          title: z.string(),
          blurb: z.string(),
          repo: z.string(),
          tag: z.string(),
          year: z.number(),
          featured: z.boolean().default(false),
        })),
      }),
    }),
    profile: defineCollection({
      type: "data",
      source: { include: "profile.yml" },
      schema: z.object({
        name: z.string(),
        email: z.string(),
        location: z.string(),
        site: z.string(),
        version: z.string(),
        versions: z.array(z.object({
          label: z.string(),
          url: z.string(),
        })),
        blurb: z.string(),
        socials: z.array(z.object({
          label: z.string(),
          icon: z.string(),
          url: z.string(),
          color: z.string(),
        })),
      }),
    }),
  },
})
