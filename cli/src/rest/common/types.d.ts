interface CreditSource {
  minter: string
  kyc: string
  tokenId: number
  amount: number
}

interface CreditRetireRequest {
  minter: string
  kyc: string
  tokenId: number
  amount: number
  reason: string
}

interface CreditRetireResponse {
  message: string,
  updateHash: string
}

export {
  CreditSource,
  CreditRetireRequest,
  CreditRetireResponse
}
