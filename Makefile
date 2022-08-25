LIGO = ligo

.PHONY = test build all clean

SRC := .
BUILD := build
TEST := tests

SOURCES := $(wildcard $(SRC)/*.mligo)
TARGETS := $(patsubst $(SRC)/%.mligo, $(BUILD)/%.tz, $(SOURCES))

TESTS := $(wildcard $(TEST)/test_*.mligo)
TEST_TARGETS := $(patsubst $(TEST)/%.mligo, $(BUILD)/%.output, $(TESTS))

build: $(TARGETS)

$(BUILD)/%.tz: $(SRC)/%.mligo
	$(LIGO) compile contract $< --entry-point main --output-file $@

test: $(TEST_TARGETS)

$(BUILD)/%.output: $(TEST)/%.mligo
	$(LIGO) run test $< > $@

all: build test

clean:
	rm -f build/*
