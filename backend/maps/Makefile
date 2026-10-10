.PHONY: dev run test vet docker emulators seed

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
