all: generate

build:
	@bun run build

dev:
	@bun run dev

generate:
	@bun run generate

preview:
	@bun run preview

start:
	@bun run start

# Remove everything generated: PureScript build output, generated shims,
# declarations, FFI companion stubs, and Nuxt/content artifacts. All of it
# is rebuilt by `bun run purs:build` / `bun run dev`.
clean:
	@rm -rf .output .nuxt dist node_modules/.cache
	@rm -rf output .purs-shims app/types/purs .purs-repl .data/content
	@rm -f packages/vue-bridge/src/Vue.js packages/vue-bridge/src/Vue.d.ts
	@find app -type f -name "[A-Z]*.js" -not -path "*/node_modules/*" -delete

# Also drop dependency caches (spago registry checkout, node_modules).
distclean: clean
	@rm -rf .spago node_modules

.PHONY: all build dev generate preview start clean distclean
