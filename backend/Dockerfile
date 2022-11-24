FROM golang:bullseye AS builder
COPY . backend
WORKDIR backend
RUN make static

FROM debian:bullseye
COPY --from=builder /go/backend/bin/server /bin/server
ENTRYPOINT ["/bin/server"]