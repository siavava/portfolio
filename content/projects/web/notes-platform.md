---
title: "Notes Platform"
date: 2023-05-03
tag: "design / web"
repo: "https://github.com/lostflux/notes-platform"
url: "https://notes-platform.amittai.studio"
featured: false
tech:
  - "design"
  - "React"
  - "JavaScript"
  - "Sass"
  - "Firebase"
summary: "NotePad, a board of draggable, resizable sticky notes backed by the Firebase Realtime Database, with live sync and client-side search."
---

**NotePad** is a board of sticky notes: create a note, drag it anywhere,
resize it, and stack it over the others. Built with
[React][reactjs],
[TypeScript][typescriptlang], and
[Sass][sass-lang], bundled with [Vite][vitejs],
with the [Firebase][firebase] Realtime Database holding
the notes.

Firebase carries the backend, so there is no server to run. A single
service, `services/datastore.ts`, wraps one Realtime Database reference,
`notes`. `onNotesValueChange` subscribes with `.on('value')` and fires a
callback on every snapshot; `addNote` pushes a new record, `updateNote`
calls `.child(id).update`, and `deleteNote` calls `.child(id).remove`. The
`Notes` container keeps the snapshot as a `Map<string, NoteType>` and
re-renders whenever Firebase pushes a change, so a note moved in one tab
lands in another without a reload.

Every note carries its own geometry. A `NoteType` is `title` and `text` plus
`x`, `y`, `width`, `height`, and a `z` index. Dragging and resizing write
those coordinates back, and focusing a note lifts its `z` above the rest so
it comes to the front. Bodies render as Markdown through
[react-markdown][react-markdown], and a search
box filters the board by substring across each note's title and text,
highlighting the matches in place. Because persistence and sync are
delegated to Firebase, the code that remains is mostly the note-editing
surface itself.

[reactjs]:        https://reactjs.org
[typescriptlang]: https://www.typescriptlang.org
[sass-lang]:      https://sass-lang.com
[vitejs]:         https://vitejs.dev
[firebase]:       https://firebase.google.com
[react-markdown]: https://github.com/remarkjs/react-markdown
