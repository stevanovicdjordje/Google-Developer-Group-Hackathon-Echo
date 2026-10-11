# Build context: backend/onboarding
#   docker build -t eho-onboarding .
# Cloud Run: set FIREBASE_PROJECT_ID, FIREBASE_API_KEY, EHO_BASE_URL, EHO_APP_URL,
# EHO_COOKIE_SECURE=true; credentials come from the service account (ADC).
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/eho-web ./cmd/eho-web

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/eho-web /app/eho-web
ENV PORT=8080
EXPOSE 8080
USER nonroot
ENTRYPOINT ["/app/eho-web"]
