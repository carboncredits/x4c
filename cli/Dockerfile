FROM node:18
WORKDIR /app
COPY . .
RUN npm install -g typescript && npm install
CMD [ "node", "dist/rest/server/server.js" ]