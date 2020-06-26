noop:
	@echo "noop. there is no default target."

build:
	podman build -t captest .

run:
	podman run --name=captest --rm -it localhost/captest

shell:
	podman run --name=captest --rm -it localhost/captest /bin/bash

clean:
	podman kill captest ||:
	podman rmi localhost/captest ||:
