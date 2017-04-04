NAME = cheggwpt/php7-nginx-extras
VERSION = edge

.PHONY: all build test tag_latest release ssh

all: build tag

build:
	docker build -t $(NAME):$(VERSION) .

tag:
	docker tag $(NAME):$(VERSION) $(NAME):$(VERSION)

run:
	docker run --rm -p 80:80 -i -t $(NAME):$(VERSION)

release: tag_latest
	@if ! docker images $(NAME) | awk '{ print $$2 }' | grep -q -F $(VERSION); then echo "$(NAME) version $(VERSION) is not yet built. Please run 'make build'"; false; fi
	docker push $(NAME)
	@echo "*** Don't forget to create a tag. git tag rel-$(VERSION) && git push origin rel-$(VERSION)"

