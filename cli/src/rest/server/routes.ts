import express from 'express';
import * as controller from './controller';

const router = express.Router();

/* Note, in its current state this API is just demonstration.
 * There is no checking of authorisation to perform any of the
 * REST calls for now. */

// <><><> GET <><><> 

// Sources of credits
router.get('/credit/sources', controller.getCreditSources);

// <><><> POST <><><>

// Retiring a credit using it's ID
router.post('/retire/:creditId', controller.retireCredit);

export default router