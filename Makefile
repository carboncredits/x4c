.PHONY = build test

# Path Related
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(dir $(MKFILE_PATH))
RELEASE_DIR := ${MKFILE_DIR}bin

build: vet x4cli server

x4cli server:
	go build -o ${RELEASE_DIR}/$@ ${MKFILE_DIR}cmd/$@/

test: tzclient x4c tzkt

tzclient x4c:
	go test ${MKFILE_DIR}pkg/$@/

vet:
	go vet ${MKFILE_DIR}pkg/tzclient
	go vet ${MKFILE_DIR}pkg/tzkt
	go vet ${MKFILE_DIR}pkg/x4c
	go vet ${MKFILE_DIR}cmd/server
	go vet ${MKFILE_DIR}cmd/x4cli

fmt:
	go fmt ${MKFILE_DIR}pkg/tzclient
	go fmt ${MKFILE_DIR}pkg/tzkt
	go fmt ${MKFILE_DIR}pkg/x4c
	go fmt ${MKFILE_DIR}cmd/server
	go fmt ${MKFILE_DIR}cmd/x4cli
