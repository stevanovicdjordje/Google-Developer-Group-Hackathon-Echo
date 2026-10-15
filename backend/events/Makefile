.PHONY: dev run test test-emulator vet seed docker deploy

dev:            ## events API on :8084 against the emulators started by backend/maps `make dev`
	./scripts/dev.sh

run:
	FIREBASE_PROJECT_ID=demo-eho PORT=8084 go run ./cmd/api

test:
	go test ./...

test-emulator:  ## also runs the Firestore store test (emulator on 127.0.0.1:8081)
	FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 go test -count=1 ./...

vet:
	go vet ./...

seed:           ## demo agenda into the demo event (EVENT=<id>, default devfest)
	FIREBASE_PROJECT_ID=$${FIREBASE_PROJECT_ID:-demo-eho} FIRESTORE_EMULATOR_HOST=$${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8081} \
		go run ./cmd/seed -event $${EVENT:-devfest}

docker:
	docker build -t eho-events .

deploy:         ## make deploy PROJECT=<firebase-project> [REGION=europe-west1] (Cloud Run; GEMINI_API_KEY from .env → Secret Manager)
	./scripts/deploy.sh $(PROJECT) $(REGION)
