FROM golang:alpine AS builder
RUN apk --no-cache add ca-certificates make
COPY . backend
WORKDIR backend
RUN make static

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /go/backend/bin/server /bin/server
ENTRYPOINT ["/bin/server"]