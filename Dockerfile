FROM debian:bookworm-slim
LABEL description="Artifact for the ICFP 2024 paper *Double-Ended Bit-Stealing for Algebraic Data Types*"

# Install tools
RUN apt-get update
RUN apt-get install -y sudo make gcc libgmp-dev time automake patch git bsdextrautils cmake build-essential
RUN apt-get install -y sudo wget

# Clean up image.
RUN apt-get clean autoclean
RUN apt-get autoremove --yes
RUN rm -rf /var/lib/{apt,dpkg,cache,log}/

# Set up user
RUN adduser --gecos '' --disabled-password artifact
RUN echo "artifact ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers
USER artifact
WORKDIR /home/artifact/

# Install MLKit
ADD --chown=artifact https://github.com/melsman/mlkit/releases/download/v4.7.11/mlkit-bin-dist-linux.tgz ./
RUN tar xf mlkit-bin-dist-linux.tgz
RUN make -C mlkit-bin-dist-linux install PREFIX=/home/artifact/mlkit
ENV PATH=/home/artifact/mlkit/bin:$PATH
ENV SML_LIB=/home/artifact/mlkit/lib/mlkit
RUN rm -rf mlkit-bin-dist-linux*
RUN mlkit -c /home/artifact/mlkit/lib/mlkit/basis/basis.mlb

# Install MLton
ADD --chown=artifact https://github.com/MLton/mlton/releases/download/on-20210117-release/mlton-20210117-1.amd64-linux-glibc2.31.tgz ./
RUN tar xf mlton-20210117-1.amd64-linux-glibc2.31.tgz
RUN make -C mlton-20210117-1.amd64-linux-glibc2.31 install PREFIX=/home/artifact/mlton
ENV PATH=/home/artifact/mlton/bin:$PATH
RUN rm -rf mlton-20210117-1.amd64-linux-glibc2.31*

# Install SML/NJ
RUN mkdir smlnj
WORKDIR /home/artifact/smlnj
RUN wget -P ./ http://smlnj.cs.uchicago.edu/dist/working/110.99.4/config.tgz
RUN tar zxf config.tgz
RUN rm config.tgz
RUN config/install.sh
ENV PATH=/home/artifact/smlnj/bin:$PATH

WORKDIR /home/artifact

# Copy artifact files into image.
RUN mkdir debs-icfp24
COPY --chown=artifact ./ debs-icfp24/

CMD bash
