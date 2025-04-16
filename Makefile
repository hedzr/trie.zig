
all: build test

lint:
	@printf "\n\n\e[0;38;2;133;133;133m>>> %s ------------------\e[0m\n" "linting"
	zig fmt --check .

build: lint
	@printf "\n\n\e[0;38;2;133;133;133m>>> %s ------------------\e[0m\n" "building"
	zig build test --verbose

test:
	@printf "\n\n\e[0;38;2;133;133;133m>>> %s ------------------\e[0m\n" "coverage testing"
	zig test --test-no-exec -femit-bin=zig-out/bin/tester src/root.zig
	kcov --clean --include-pattern=src/ --exclude-pattern=lib/std --exclude-pattern=lib/zig zig-out/coverage zig-out/bin/tester
	@jq '. | "coverage: \(.percent_covered), covered: \(.covered_lines) / total \(.total_lines) lines."' ./zig-out/coverage/tester/coverage.json
	@#

bt:
	TEST_FILTER="${F}" zig build test --summary all -freference-trace

tip:
	@printf "\e[0;38;2;133;133;133m>>> %s\e[0m\n" "TIP"

err:
	@printf "\e[0;33;1;133;133;133m>>> %s\e[0m\n" "ERR" 1>&2
