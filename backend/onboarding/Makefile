.PHONY: dev seed test test-emulator vet

EMU = FIREBASE_PROJECT_ID=$${FIREBASE_PROJECT_ID:-demo-eho} FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 \
	FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199

dev:            ## emulators + map API (if not running) + this app on :8085
	./scripts/dev.sh

seed:           ## all demo data: map (backend/maps), agenda (backend/events), onboarding
	./scripts/seed.sh

test:           ## unit + HTTP tests (in-memory; the emulator test is skipped)
	go test ./...

test-emulator:  ## the HTTP flow against the running emulators
	$(EMU) go test -count=1 -run TestAgainstEmulators -v ./internal/app/

vet:
	go vet ./...
