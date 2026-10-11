.PHONY: dev run test test-emulator vet seed docker

dev:            ## Find API on :8083 against the emulators started by backend/maps `make dev`
	./scripts/dev.sh

run:
	FIREBASE_PROJECT_ID=demo-eho PORT=8083 go run ./cmd/api

test:
	go test ./...

test-emulator:  ## also runs the Firestore store test (emulator on 127.0.0.1:8081)
	FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 go test -count=1 ./...

vet:
	go vet ./...

seed:           ## 20 demo attendees present at the published demo event (EVENT=<id> picks another)
	FIREBASE_PROJECT_ID=$${FIREBASE_PROJECT_ID:-demo-eho} FIRESTORE_EMULATOR_HOST=$${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8081} \
		go run ./cmd/seed $${EVENT:+-event $$EVENT}

docker:
	docker build -t eho-find .
