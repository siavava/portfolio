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

clean:
	@rm -rf .output .nuxt dist node_modules/.cache

install:
	@bun install

lint:
	@bun run lint

lint-md:
	@bun run lint:md

typecheck:
	@bun run typecheck

style-check:
	@bunx eslint .

.PHONY: all build dev generate preview start clean install lint lint-md typecheck style-check
