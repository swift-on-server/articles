SHELL=/bin/bash

build:
	swift build

release:
	swift build -c release

test:
	swift test --parallel

test-with-coverage:
	swift test --parallel --enable-code-coverage

clean:
	rm -rf .build

check:
	./scripts/run-checks.sh

format:
	./scripts/run-swift-format.sh --fix

unidoc:
	unidoc compile -I .. \
--ci fail-on-errors \
--package-name articles \
--define DARWIN

unidoc-local:
	unidoc local -i . 

