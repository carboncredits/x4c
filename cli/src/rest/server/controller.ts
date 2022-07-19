import { Request, Response, NextFunction } from 'express';
import { CreditSource } from '../common';

const getCreditSources = async (req: Request, res: Response, next: NextFunction) => {
    const data: CreditSource[] = [
        {
            uid : "abcdef",
            name: "University of Cambridge, Department of Computer Science",
            credits: 1234
        }
    ]
    return res.status(200).json({
        data: data
    })
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