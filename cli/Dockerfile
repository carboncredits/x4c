FROM node:18
WORKDIR /app
COPY ["package.json", "package-lock.json*", "./*.js", "./"]
RUN npm install -g typescript && npm install
COPY . .
RUN tsc
CMD [ "node", "dist/rest/server/server.js" ]