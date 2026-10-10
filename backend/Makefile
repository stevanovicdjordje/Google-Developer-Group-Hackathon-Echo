.PHONY: dev run test vet lint docker emulators

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
