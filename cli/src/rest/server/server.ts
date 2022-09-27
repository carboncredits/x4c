import express, { Express, Router } from "express";
import http from 'http'
import router from './routes'
import X4CClient from '../../x4c'

// Change the URLs to use Tzkt or Tzstats APIs
const x4cClient = X4CClient.getInstance(
    "https://rpc.kathmandunet.teztnets.xyz",
    "https://api.kathmandunet.tzkt.io",
    "https://kathmandunet.tzkt.io"
)

x4cClient.loadClientState().then(() => {
    const server: Express = express();

    // Set up our own middleware for the API
    server.use((req, res, next) => {
        res.header('Access-Control-Allow-Origin', '*');
        res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE');
        res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
        next();
    })
    
    // Middleware for decoding JSON bodies
    server.use(express.json());

    // The API endpoints
    server.use('/', router);
    
    // HTTP server with configurable port number
    const httpServer = http.createServer(server);
    const PORT: number = process.env.X4CPORT ? parseInt(process.env.X4CPORT) : 9000;
    
    httpServer.listen(PORT, () => {
        console.log(`x4c REST server is listening at http://localhost:${PORT}`);
    })
})