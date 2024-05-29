.PHONY: all
all:
	make -C mlkit-bench all
	make -C demo all

.PHONY: clean
clean:
	rm -rf *~ debs-icfp24.tar.gz
	make -C src clean
	make -C mlkit-bench clean
	make -C demo clean

.PHONY: docker
docker: debs-icfp24.tar.gz

debs-icfp24.tar.gz: Dockerfile
	docker build --platform linux/amd64 -t debs-icfp24 .
	docker save debs-icfp24:latest | gzip > $@

.PHONY: mlkit
mlkit: mlkit/bin/mlkit

mlkit/bin/mlkit:
	(cd mlkit; ./autobuild)
	(cd mlkit; ./configure --with-compiler=mlkit)
	(cd mlkit; make mlkit && make mlkit_basislibs)

# To load and run:

# docker load -i debs-icfp24.tar.gz
# docker run --platform linux/amd64 -it debs-icfp24:latest
