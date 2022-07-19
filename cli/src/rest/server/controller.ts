import { Request, Response, NextFunction } from 'express';
import { CreditSource } from '../common';

import X4CClient from '../../x4c';

const getCreditSources = async (req: Request, res: Response, next: NextFunction) => {
    
    try {
        const x4c = X4CClient.getInstance();
        const custodian = await x4c.getCustodianContract(req.params["custodianID"])
        const storage = await custodian.getStorage()
        const ledger = await storage.ledger()
        return res.status(200).json({
            data: ledger
        })
    } catch {
        return res.status(404).send('Not found')
    }
}

const retireCredit = async (req: Request, res: Response, next: NextFunction) => {
    const id = req.params.creditId
    return res.status(200).json({
        message: `Successfully retired credit ${id}`
    })
}

export {
    getCreditSources,
    retireCredit
}