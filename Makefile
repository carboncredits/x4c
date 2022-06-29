CONTRACTS = fa2.mligo custodian.mligo
TESTS = test.mligo

.PHONY = test build all clean

BUILT_CONTRACTS = $(CONTRACTS:%.mligo=build/%.tz)
OUTPUT_TESTS = $(TESTS:%.mligo=build/%.test.output)

build: $(BUILT_CONTRACTS)

$(BUILT_CONTRACTS): $(CONTRACTS)
	ligo compile contract $< --entry-point main --output-file $@

test: $(OUTPUT_TESTS)

$(OUTPUT_TESTS): $(TESTS)
	ligo run test $< > $@

all: build test

clean:
	rm -f build/*
