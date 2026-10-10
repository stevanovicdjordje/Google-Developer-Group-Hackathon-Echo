.PHONY: dev run test vet docker emulators seed rules-test deploy

dev:            ## emulators + API (one command)
	./scripts/dev.sh

emulators:
	cd firebase && firebase emulators:start --project demo-eho

run:
	FIREBASE_PROJECT_ID=demo-eho go run ./cmd/api

test:
	go test ./...

vet:
	go vet ./...

docker:
	docker build -t eho-api .

seed:           ## publish the demo event (needs `make dev` running)
	go run ./cmd/seed

rules-test:     ## security-rule tests (needs `make dev` running)
	FIRESTORE_EMULATOR_HOST=127.0.0.1:8081 STORAGE_EMULATOR_HOST=http://127.0.0.1:9199 go test -count=1 ./internal/rulestest/

deploy:         ## make deploy PROJECT=<firebase-project> [REGION=europe-west1] [WEB_BUILD=...]
	./scripts/deploy.sh $(PROJECT) $(REGION)
