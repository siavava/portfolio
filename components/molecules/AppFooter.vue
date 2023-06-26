<template>
  <footer class="styled-footer">
    <div class="footer-inner">
      <!-- <div class="styled-links">
        <StyledButton href="/">
          home
        </StyledButton>
        <StyledButton href="/blog">
          blog
        </StyledButton>
      </div> -->
      <div class="left-section">
        {{ msg[Math.floor(Math.random() * msg.length)] }}
      </div>
      <div class="right-section">
        <div class="year">
          {{ new Date().getFullYear() }}
        </div>
        <div
          class="clock"
          @click="toggleComment"
        >
          <div class="clock-face">
            <div class="hand hour-hand" />
            <div class="hand min-hand" />
            <div class="hand second-hand" />
          </div>
        </div>
        <div id="clock-info">
          <span class="time-zone-inner-text">
            {{ timeZoneInfo }}
          </span>
        </div>
      </div>
    </div>
    <div
      :id="`footer-comment-${identifier}`"
      class="footer-inner hide"
    >
      <div class="footer-paragraph">
        <ContentRenderer
          class="markdown-comment"
          :value="parsedMarkdown"
        />
      </div>
    </div>
  </footer>
</template>

<script lang="ts">
import markdownParser from "@nuxt/content/transformers/markdown";

export default {
  name: "AppFooter",
  props: {
    identifier: {
      type: String,
      required: true,
    },
  },
  async setup(props) {
    return {
      parsedMarkdown: await markdownParser.parse(
        "footer-comment",
        `I’m reciting that _quality affects all aspects of my pursuits_.
        I want to imbue quality in everything I do.
        This skill develops while _doing_.
        Not thinking, not imagining, _doing_.
        It is learned through learning and experimenting and consistency and pacing.`,
      ),
    };
  },
  data() {
    return {
      msg: [
        "Find flow.",
        "Sit with your ambient ambition.",
        "Shine, constantly and steadily.",
        "Pray at the altar of hard work.",
      ],
    };
  },
  watch: {
    timeZoneInfo() {
      this.$forceUpdate();
    },
  },
  mounted() {
    this.tick();
  },
  methods: {
    tick() {
      const secondHands = document.getElementsByClassName("second-hand") as HTMLCollectionOf<HTMLElement>;
      const minutesHands = document.getElementsByClassName("min-hand")! as HTMLCollectionOf<HTMLElement>;
      const hourHands = document.getElementsByClassName("hour-hand")! as HTMLCollectionOf<HTMLElement>;

      function setTime() {
        const now = new Date();

        const seconds = now.getSeconds();
        const secondsDegree = ((seconds / 60) * 360) + 90;
        Array.from(secondHands).forEach((hand) => {
          hand.style.transform = `rotate(${secondsDegree}deg)`;
        });

        const minutes = now.getMinutes();
        const minutesDegree = ((minutes / 60) * 360) + ((seconds / 60) * 6) + 90;

        Array.from(minutesHands).forEach((hand) => {
          hand.style.transform = `rotate(${minutesDegree}deg)`;
        });

        const hour = now.getHours();
        const hourDegree = ((hour / 12) * 360) + ((minutes / 60) * 30) + 90;

        Array.from(hourHands).forEach((hand) => {
          hand.style.transform = `rotate(${hourDegree}deg)`;
        });

        const timeZoneInfo = `${new Date()
          .toLocaleTimeString(
            [],
            {
              hour12: false,
              hour: "2-digit",
              minute: "2-digit",
              second: "2-digit",
            },
          )} ${new Date()
          .toLocaleTimeString(
            "en-us",
            {
              timeZoneName: "short",
            },
          ).split(" ")[2]}`;

        const timeZoneElements = document.getElementsByClassName("time-zone-inner-text") as HTMLCollectionOf<HTMLElement>;
        Array.from(timeZoneElements).forEach((element) => {
          element.innerText = timeZoneInfo;
        });
      }

      setInterval(setTime, 1000);
    },
    toggleComment() {
      console.log(`this.identifier: ${this.identifier}`);
      const comment = document.getElementById(`footer-comment-${this.identifier}`) as HTMLElement;
      console.log(`comment: ${JSON.stringify(comment)}`);
      if (comment.classList.contains("hide")) {
        comment.classList.remove("hide");
      } else {
        comment.classList.add("hide");
      }
    },
  },
};
</script>

<style lang="scss" scoped>
@use "../styles/footer";
@use "../styles/mixins";
@use "../styles/typography";
@use "../styles/colors";

.styled-footer {
  @include mixins.flex-center;
  flex-direction: column;
  //min-height: 0px;
  border-top: 2px solid colors.color("light-background");
  color: colors.color("primary-highlight");
  flex-direction: column;
  padding: 1em;

  .footer-inner {
    @include mixins.flex-between;
    width: 100%;
    max-width: 848px;

    &.hide {
      display: none;
    }

    .left-section {
      color: colors.color(foreground);
      font-size: 1rem;
    }

    .right-section {
      display: inline-flex;
      gap: 1em;
      position: relative;

      .year {
        font-size: 1rem;
        font-weight: 300;
        font-family: typography.font(sans-serif);
        color: colors.color(foreground);
      }
      align-items: center;
    }

    #clock-info {
      position: absolute;
      bottom: 0;
      right: 0;
      width: 120px;
      transform: translateY(-100%);
      background: rgba(colors.color(background), 0.2);
      color: colors.color(foreground);
      font-weight: 300;
      font-size: 1rem;
      padding: 0 1px;
      border-radius: 5px;
      display: inline-flex;
      justify-content: center;
      border: 1px solid;
      opacity: 0;
      transition: opacity 0.2s ease-in-out;

      & > span {
        color: colors.color(lightest-foreground);
        font-weight: 500;
      }
    }

    .clock {
      height: 1.2em;
      aspect-ratio: 1/1;
      border: 1px solid colors.color(foreground);
      border-radius: 50%;
      position: relative;
      padding: 0;

      &:hover {
        cursor: pointer;
        + #clock-info {
          opacity: 0.8 !important;
        }
      }

      .clock-face {
        position: relative;
        width: 100%;
        height: 100%;
        transform: translateY(-0.3px);

        .hand {
          width: 50%;
          background: colors.color(foreground);
          position: absolute;
          top: 50%;
          transform-origin: 100%;
          transform: rotate(90deg);
          transition: all 0.05s;
          transition-timing-function: cubic-bezier(0.1, 2.7, 0.58, 1);
        }

        .hour-hand {
          height: 1px;
        }

        .min-hand {
            height: 1px;
        }

        .second-hand {
            height: 1px;
        }
      }
    }

    .footer-paragraph {
      width: min(100%, 548px);
      color: colors.color(foreground);
      margin: 0 auto;
      padding: 60px 0;

      * {
        font-size: 0.8rem !important;
      }
    }
  }
}

</style>
