.PHONY: build
build: bin/
	odin build . -out:bin/raven

.PHONY: test
test: bin/
	odin test tests.odin -file -out:bin/tests

bin/:
	mkdir bin
