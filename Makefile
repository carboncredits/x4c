ifndef USE_DOCKER
LIGO = ligo
else
LIGO = docker run --rm -v "$(PWD)":"$(PWD)" -w "$(PWD)" ligolang/ligo:0.52.0
endif

.PHONY = test build all clean

SRC := src
BUILD := build
TEST := tests

SOURCES := $(wildcard $(SRC)/*.mligo)
TARGETS := $(patsubst $(SRC)/%.mligo, $(BUILD)/%.tz, $(SOURCES))

TESTS := $(wildcard $(TEST)/test_*.mligo)
TEST_TARGETS := $(patsubst $(TEST)/%.mligo, $(BUILD)/%.output, $(TESTS))

build: $(TARGETS)

$(BUILD)/%.tz: $(SRC)/%.mligo
	$(LIGO) compile contract -p kathmandu $< --entry-point main --output-file $@

test: $(TEST_TARGETS)

$(BUILD)/%.output: $(TEST)/%.mligo tests/common.mligo tests/assert.mligo $(SRC)/*.mligo
	$(LIGO) run test -p kathmandu $< > $@

all: build test

clean:
	rm -f build/*
