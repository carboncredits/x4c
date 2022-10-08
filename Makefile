.PHONY = build test

# Path Related
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(dir $(MKFILE_PATH))
RELEASE_DIR := ${MKFILE_DIR}bin

build: x4cli server

x4cli server:
	go build -o ${RELEASE_DIR}/$@ ${MKFILE_DIR}cmd/$@/

test: tzclient x4c

tzclient x4c:
	go test ${MKFILE_DIR}pkg/$@/
