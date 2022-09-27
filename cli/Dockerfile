FROM node:18
# node is based on debian (libev-dev needed for ligo compiler)
RUN apt-get update -qqy \
	&& apt-get install -qy wget libev-dev \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/cache/apt/*

RUN arch=$(arch | sed s/aarch64/-arm64/ | sed s/x86_64//) && \
	wget -O tezos-client "https://github.com/serokell/tezos-packaging/releases/download/v14.0-1/tezos-client${arch}"
RUN chmod 755 tezos-client
RUN mv tezos-client /bin/tezos-client
RUN tezos-client config reset
WORKDIR /app
COPY . .
RUN npm install -g typescript && npm install
CMD [ "node", "dist/rest/server/server.js" ]