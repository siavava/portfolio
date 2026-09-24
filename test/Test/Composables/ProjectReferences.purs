-- | Checks for the reader's reference list: a project link is named by
-- | what it is (dataset, profile, paper, publication, docs, article)
-- | rather than a generic "live site"; the project's own repo and link
-- | lead in that order, blanks dropping out and PDFs opening fit to the
-- | page; and a frontmatter link into the notes site takes its lesson
-- | title from the index, else a subject-index label, else its own path.
module Test.Composables.ProjectReferences (suite) where

import Prelude

import App.Composables.ProjectReferences (leadReferences, noteReference, urlTitle)
import Data.Foldable (for_)
import Data.Nullable (Nullable, notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

type TitleCase = { url :: String, title :: String, why :: String }

titleCases :: Array TitleCase
titleCases =
  [ { url: "https://huggingface.co/datasets/siavava/corpus", title: "Dataset", why: "a dataset" }
  , { url: "https://leetcode.com/u/siavava/", title: "LeetCode profile", why: "a profile" }
  , { url: "https://amittai.space/papers/dujs/erosion.pdf"
    , title: "Published paper"
    , why: "a DUJS paper, over the PDF rule"
    }
  , { url: "https://example.com/thesis.pdf", title: "Final paper", why: "a PDF" }
  , { url: "https://drive.google.com/file/d/abc/view"
    , title: "Publication"
    , why: "a Drive file"
    }
  , { url: "https://drive.google.com/uc/report.pdf"
    , title: "Final paper"
    , why: "a Drive PDF, the PDF rule first"
    }
  , { url: "https://example.com/docs", title: "Documentation", why: "a docs root" }
  , { url: "https://example.com/docs/getting-started"
    , title: "Documentation"
    , why: "a docs page"
    }
  , { url: "https://amittai.space/docs/intro"
    , title: "Documentation"
    , why: "docs on the blog, over the article rule"
    }
  , { url: "https://amittai.space/on-erosion", title: "Article", why: "a blog post" }
  , { url: "https://amittai.space/", title: "Live site", why: "the blog's home page" }
  , { url: "https://amittai.space", title: "Live site", why: "the bare blog host" }
  , { url: "https://amittai.space/\n", title: "Live site", why: "a line break after the slash" }
  , { url: "https://huggingface.co/papers/paper.pdf"
    , title: "Dataset"
    , why: "a Hugging Face PDF, the first rule winning"
    }
  , { url: "https://example.com", title: "Live site", why: "anything else" }
  ]

indexed :: String -> Nullable String
indexed = case _ of
  "/algorithms/sorting" -> notNull "Sorting"
  "/linear-algebra" -> notNull "Linear Algebra, Done Right"
  _ -> null

type SubjectCase = { path :: String, label :: String }

subjects :: Array SubjectCase
subjects =
  [ { path: "algorithms", label: "Algorithms" }
  , { path: "computer-architecture", label: "Computer Architecture" }
  , { path: "artificial-intelligence", label: "Artificial Intelligence" }
  , { path: "natural-language-processing", label: "Natural Language Processing" }
  , { path: "deep-learning", label: "Deep Learning" }
  ]

notes :: String -> String
notes path = "https://notes.amittai.studio/" <> path

suite :: Tally -> Effect Unit
suite t = do
  for_ titleCases \c ->
    expect t ("urlTitle: " <> c.why <> " reads " <> show c.title) c.title (urlTitle c.url)

  expect t "lead: no repo and no link, no lead" [] (leadReferences null null)
  expect t "lead: empty repo and link drop out like absent ones" []
    (leadReferences (notNull "") (notNull ""))
  expect t "lead: a repo alone is the project repository"
    [ { href: "https://github.com/siavava/portfolio", title: "Project repository", notes: false } ]
    (leadReferences (notNull "https://github.com/siavava/portfolio") null)
  expect t "lead: a link alone is named for what it is"
    [ { href: "https://amittai.space/on-erosion", title: "Article", notes: false } ]
    (leadReferences null (notNull "https://amittai.space/on-erosion"))
  expect t "lead: the repo leads, the link follows"
    [ { href: "https://github.com/siavava/portfolio", title: "Project repository", notes: false }
    , { href: "https://example.com", title: "Live site", notes: false }
    ]
    ( leadReferences (notNull "https://github.com/siavava/portfolio")
        (notNull "https://example.com")
    )
  expect t "lead: an empty repo drops without taking the link with it"
    [ { href: "https://example.com", title: "Live site", notes: false } ]
    (leadReferences (notNull "") (notNull "https://example.com"))
  expect t "lead: a PDF opens fit to the page and is still titled as a paper"
    [ { href: "https://example.com/thesis.pdf#view=FitV&zoom=page-fit"
      , title: "Final paper"
      , notes: false
      }
    ]
    (leadReferences null (notNull "https://example.com/thesis.pdf"))

  expect t "notes: an indexed lesson takes its title, the href kept as written"
    { href: notes "algorithms/sorting/", title: "Sorting", notes: true }
    (noteReference indexed (notes "algorithms/sorting/"))
  for_ subjects \s ->
    expect t ("notes: the unindexed " <> s.path <> " index reads " <> show s.label)
      { href: notes s.path <> "/", title: s.label, notes: true }
      (noteReference indexed (notes s.path <> "/"))
  expect t "notes: an index title beats the subject label"
    { href: notes "linear-algebra", title: "Linear Algebra, Done Right", notes: true }
    (noteReference indexed (notes "linear-algebra"))
  expect t "notes: the subject label stands in when the index lacks the subject"
    { href: notes "linear-algebra", title: "Linear Algebra", notes: true }
    (noteReference (const null) (notes "linear-algebra"))
  expect t "notes: an unknown page is titled by its path"
    { href: notes "misc/scratch/", title: "/misc/scratch", notes: true }
    (noteReference indexed (notes "misc/scratch/"))
  expect t "notes: query and fragment stay out of the lookup"
    { href: notes "algorithms/sorting?x=1#merge", title: "Sorting", notes: true }
    (noteReference indexed (notes "algorithms/sorting?x=1#merge"))
  expect t "notes: an href that isn't a URL is looked up as written"
    { href: "/deep-learning/", title: "Deep Learning", notes: true }
    (noteReference indexed "/deep-learning/")
  expect t "notes: the lookup key is what the index is asked for"
    { href: notes "a/b//", title: "asked /a/b", notes: true }
    (noteReference (\path -> notNull ("asked " <> path)) (notes "a/b//"))
