FROM golang:latest AS builder
COPY . backend
WORKDIR backend
RUN make build

FROM scratch
COPY --from=builder /go/backend/bin/server /bin/server
ENTRYPOINT ["/bin/server"]