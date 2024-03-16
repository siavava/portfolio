<template>
  <section class="jobs">
    <ProseH1 id="education">
      Education
    </ProseH1>
    <div class="jobs-list">
      <div
        v-for="job, i in jobs"
        :key="i"
        class="work-item"
      >
        <div class="range">
          <span class="date">{{ job.start }}</span>
          <span class="date"> &mdash; </span>
          <span class="date"> {{ job.end }} </span>
        </div>
        <div class="work-info">
          <ProseA
            :href="job.url"
            class="link"
            fancy
            bold
          >
            <span>
              {{ job.title }}
              <span class="company">
                at
                {{ job.company }}
              </span>
            </span>
          </ProseA>

          <ContentDoc
            class="jobs-doc"
            :value="job"
          />
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
// @ts-ignore
// eslint-disable-next-line import/no-unresolved
import type { MarkdownParsedContent } from "@nuxt/content/dist/runtime/types"

// read 'job-info' data from Markdown files
const { data: jobsData } = await useAsyncData(
  `school-${useRoute().path}`,
  async () => {
    const _jobsData = await queryContent<MarkdownParsedContent>()
      .where({ category: "school-info" })
      .sort({ date: -1 })
      .find()
    return _jobsData
  },
)

// parse job info and store in an array, sorted by date
// const jobs = Array<ParsedJobInfo>();
const jobs = jobsData.value || []

</script>

<script lang="ts">
export default {
  name: "Education",
}
</script>

<style lang="sass">
@use "@/styles/typography"
@use "@/styles/mixins"
@use "@/styles/colors"

.jobs-doc
  .prose-table
    font-size: typography.font-size(xs) !important

.work-item
  @include mixins.split
  display: flex
  flex-direction: row
  font-size: typography.font-size(m)

  &:not(:first-of-type)
    margin-top: 2em

</style>
