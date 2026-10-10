.PHONY: dev run test test-emulator vet docker replay

dev:            ## Echo API on :8082 against the emulators started by backend/maps `make dev`
	./scripts/dev.sh

run:
	FIREBASE_PROJECT_ID=demo-eho PORT=8082 go run ./cmd/api

test:
	go test ./...

test-emulator:  ## also runs the Firestore store test (emulator on 127.0.0.1:8081)
	FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 go test -count=1 ./...

vet:
	go vet ./...

docker:
	docker build -t eho-echo .

replay:         ## replay the demo keynote into the seeded demo event (SPEED=2 by default)
	FIREBASE_PROJECT_ID=$${FIREBASE_PROJECT_ID:-demo-eho} FIRESTORE_EMULATOR_HOST=$${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8081} \
		go run ./cmd/replay -speed $${SPEED:-2} $${EVENT:+-event $$EVENT}
