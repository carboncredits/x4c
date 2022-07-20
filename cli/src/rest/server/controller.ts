import { Request, Response, NextFunction } from 'express';
import { CreditRetireRequest } from '../common';

import X4CClient from '../../x4c';

const getCreditSources = async (req: Request, res: Response, next: NextFunction) => {
    
    try {
        const x4c = X4CClient.getInstance();
        const custodian = await x4c.getCustodianContract(req.params.custodianID)
        const storage = await custodian.getStorage()
        const ledger = await storage.ledger()
        return res.status(200).json({
            data: ledger.map(entry => ({
                tokenId: entry.token_id,
                kyc: entry.kyc,
                amount: entry.amount,
                minter: entry.minter
            }))
        })
    } catch {
        return res.status(404).send('Not found')
    }
}

const retireCredit = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const data = req.body as CreditRetireRequest
        
        const x4c = X4CClient.getInstance();
        const custodian = await x4c.getCustodianContract(req.params.custodianID, "UoCCustodian")
        const updateHash = await custodian.retire(data.minter, data.tokenId, data.amount, data.kyc, data.reason)
        
        return res.status(200).json({
            message: `Successfully retired credits`,
            update: updateHash,
        })
    } catch {
        return res.status(404).send('Not found')
    }
}

export {
    getCreditSources,
    retireCredit
}