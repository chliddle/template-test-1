.PHONY: build test run fmt vet

build:
	CGO_ENABLED=0 go build -o bin/template-test-1 .

test:
	go test ./...

fmt:
	gofmt -l .

vet:
	go vet ./...

run: build
	ENVIRONMENT=local ./bin/template-test-1
