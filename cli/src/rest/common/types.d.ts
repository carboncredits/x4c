interface CreditSource {
  minter: string
  tzstatsMinterUrl: string
  kyc: string
  tzstatsCustodianUrl: string
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
  updateHash: string,
  tzstatsUpdateHashUrl: string
}

export {
  CreditSource,
  CreditRetireRequest,
  CreditRetireResponse
}
