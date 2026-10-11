# Build context: backend/onboarding
#   docker build -t eho-onboarding .
#   docker run -p 8080:8080 -v eho-data:/data eho-onboarding
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# No CGO: modernc.org/sqlite is pure Go, so the binary is fully static.
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/eho-web ./cmd/eho-web \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/eho-seed ./cmd/seed \
 && mkdir -p /out/data/uploads

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/eho-web /out/eho-seed /app/
COPY --from=build --chown=65532:65532 /out/data /data
ENV PORT=8080 \
    EHO_DB_PATH=/data/eho.db \
    EHO_UPLOAD_DIR=/data/uploads
VOLUME /data
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/app/eho-web"]
