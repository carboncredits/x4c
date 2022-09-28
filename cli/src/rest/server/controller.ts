import { Request, Response, NextFunction } from 'express';
import { CreditRetireRequest, CreditRetireResponse, CreditSource, OperationInfo } from '../common';

import X4CClient from '../../x4c';

const getCreditSources = async (req: Request, res: Response, next: NextFunction) => {

    try {
        const x4c = X4CClient.getInstance();
        const indexerUrl = x4c.getIndexerUrl();
        const custodian = await x4c.getCustodianContract(req.params.custodianID)
        const storage = await custodian.getStorage()
        const ledger = await storage.ledger()
        return res.status(200).json({
            data: ledger.map((entry): CreditSource => ({
                tokenId: entry.token_id,
                tzstatsMinterUrl: `${indexerUrl}/${entry.token_id}`,
                kyc: entry.kyc,
                tzstatsCustodianUrl: `${indexerUrl}/${custodian.contract.address}`,
                amount: entry.amount,
                minter: entry.minter
            }))
        })
    } catch (error) {
        console.error(error);
        return res.status(404).send('Not found')
    }
}

const retireCredit = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const data = req.body as CreditRetireRequest

        const x4c = X4CClient.getInstance();
        const indexerUrl = x4c.getIndexerUrl();
        const custodian = await x4c.getCustodianContract(req.params.custodianID, "CustodianOperator")
        const updateHash = await custodian.retire(data.minter, data.tokenId, data.amount, data.kyc, data.reason)

        const retireResponse: CreditRetireResponse = {
            message: `Successfully retired credits`,
            updateHash,
            tzstatsUpdateHashUrl: `${indexerUrl}/${updateHash}`
        }

        return res.status(200).json({ data: retireResponse });
    } catch {
        return res.status(404).send('Not found')
    }
}

const getOperation = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const x4c = X4CClient.getInstance();
        const apiClient = x4c.getApiClient();
        const op = await apiClient.getOperation(req.params.opHash);
        const response: OperationInfo = {
            data: op
        }
        return res.status(200).json(response);
    } catch (error) {
        console.error(error);
        return res.status(404).send('Not found')
    }
}

const getIndexerUrl = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const x4c = X4CClient.getInstance();
        const response: { data : string } = {
            data: x4c.getIndexerUrl()
        }
        return res.status(200).json(response);
    } catch (error) {
        console.error(error);
        return res.status(404).send('Not found')
    }
}

const getEvents = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const x4c = X4CClient.getInstance();
        const apiClient = x4c.getApiClient();
        const op = await apiClient.getEvents(req.params.opHash);
        const response: OperationInfo = {
            data: op
        }
        return res.status(200).json(response);
    } catch (error) {
        console.error(error);
        return res.status(404).send('Not found')
    }
}

export {
    getCreditSources,
    getOperation,
    getEvents,
    retireCredit,
    getIndexerUrl
}