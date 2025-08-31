SHELL=/bin/bash

baseUrl = https://raw.githubusercontent.com/BinaryBirds/github-workflows/refs/heads/main/scripts

check: symlinks deps

symlinks:
	curl -s $(baseUrl)/check-broken-symlinks.sh | bash
	
language:
	curl -s $(baseUrl)/check-unacceptable-language.sh | bash
	
deps:
	curl -s $(baseUrl)/check-local-swift-dependencies.sh | bash
	
lint:
	curl -s $(baseUrl)/run-swift-format.sh | bash

fmt:
	swiftformat .

format:
	curl -s $(baseUrl)/run-swift-format.sh | bash -s -- --fix



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

docker-run:
	docker run --rm -v $(pwd):/app -it swift:6.0