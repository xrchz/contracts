ARG APE_VERSION=0.6.21
FROM apeworx/ape:${APE_VERSION}

# Install Foundry
ARG FOUNDRY_VERSION=nightly-602460eb99e1645eab970bacc5a6d01368a07457
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git && \
    apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/ && \
    curl -sL https://github.com/foundry-rs/foundry/releases/download/${FOUNDRY_VERSION}/foundry_nightly_linux_amd64.tar.gz \
        | tar xzf - -C /usr/local/bin/

USER harambe
WORKDIR /home/harambe/project
COPY ape-config.yaml .
