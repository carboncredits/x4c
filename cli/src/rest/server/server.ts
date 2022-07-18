import express, { Express, Router } from "express";
import http from 'http'
import router from './routes'

const server: Express = express();

// Middleware for decoding JSON bodies
server.use(express.json());

// Set up our own middleware for the API
server.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    next();
})

// The API endpoints
server.use('/', router);

// HTTP server with configurable port number
const httpServer = http.createServer(server);
const PORT: number = process.env.X4CPORT ? parseInt(process.env.X4CPORT) : 9000;

httpServer.listen(PORT, () => {
    console.log(`x4c REST server is listening at http://localhost:${PORT}`);
})