.PHONY = build test

# Path Related
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MKFILE_DIR := $(dir $(MKFILE_PATH))
RELEASE_DIR := ${MKFILE_DIR}bin

build: go.sum vet x4cli server

x4cli server:
	go build -o ${RELEASE_DIR}/$@ ${MKFILE_DIR}cmd/$@/

test: go.sum tzclient x4c tzkt servertest

tzclient x4c tzkt:
	go test ${MKFILE_DIR}pkg/$@/

servertest:
	go test ${MKFILE_DIR}cmd/server/

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

docker: Dockerfile server
	docker build .

go.sum: go.mod
	go mod tidy

static: go.sum
	CGO_ENABLED=0 GOOS=linux go build -o ${RELEASE_DIR}/server ${MKFILE_DIR}cmd/server/
