# BTCPerpetuals

A decentralized perpetual futures trading platform for Bitcoin with AMM-based liquidity provision on the Stacks blockchain.

## Overview

BTCPerpetuals is a cross-chain AMM liquidity pool for Bitcoin perpetual futures that enables users to trade leveraged Bitcoin positions while providing liquidity providers with yield opportunities. The protocol operates entirely on-chain using Clarity smart contracts on the Stacks blockchain.

## Features

- **Perpetual Futures Trading**: Open long and short positions on Bitcoin with up to 10x leverage
- **AMM Liquidity Pool**: Automated Market Maker model for efficient liquidity provision
- **Leverage Trading**: Support for leveraged positions up to 10x with collateral management
- **Liquidity Provision**: Earn fees by providing liquidity to the trading pool
- **Price Oracle Integration**: Real-time price feeds for accurate position valuation
- **Position Management**: Open, close, and monitor trading positions with health ratios
- **Fee Collection**: Trading fees distributed to protocol and liquidity providers
- **Emergency Controls**: Circuit breaker mechanisms for enhanced security

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity (version 2)
- **Epoch**: 2.5
- **Maximum Leverage**: 10x
- **Trading Fee**: 0.3% (30 basis points)
- **Liquidation Threshold**: 80%
- **Oracle Price Validity**: 10 blocks

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development framework
- [Node.js](https://nodejs.org/) (v18 or higher)
- [Git](https://git-scm.com/)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd BTCPerpetuals
```

2. Navigate to the contract directory:
```bash
cd BTCPerpetuals_contract
```

3. Install dependencies:
```bash
npm install
```

4. Run tests:
```bash
npm test
```

## Usage Examples

### Adding Liquidity

Provide STX tokens to the liquidity pool to earn trading fees:

```clarity
;; Add 1000 STX to the liquidity pool
(contract-call? .BTCPerpetuals add-liquidity u1000000000) ;; 1000 STX in microSTX
```

### Opening a Position

Open a leveraged Bitcoin perpetual position:

```clarity
;; Open a 5x long position with 100 STX collateral
(contract-call? .BTCPerpetuals open-position u100000000 u5 true)

;; Open a 3x short position with 200 STX collateral
(contract-call? .BTCPerpetuals open-position u200000000 u3 false)
```

### Closing a Position

Close an existing position to realize profits or losses:

```clarity
;; Close position with ID 1
(contract-call? .BTCPerpetuals close-position u1)
```

### Removing Liquidity

Withdraw liquidity and earned fees:

```clarity
;; Remove 500 liquidity tokens
(contract-call? .BTCPerpetuals remove-liquidity u500000000)
```

## Contract Functions Documentation

### Public Functions

#### `add-liquidity (stx-amount uint)`
Add STX tokens to the liquidity pool and receive liquidity tokens in return.

**Parameters:**
- `stx-amount`: Amount of STX to add (in microSTX)

**Returns:** Number of liquidity tokens minted

#### `remove-liquidity (liquidity-amount uint)`
Remove liquidity from the pool and receive STX tokens back.

**Parameters:**
- `liquidity-amount`: Amount of liquidity tokens to burn

**Returns:** Amount of STX returned

#### `open-position (collateral-amount uint) (leverage uint) (is-long bool)`
Open a new perpetual futures position.

**Parameters:**
- `collateral-amount`: STX collateral amount (in microSTX)
- `leverage`: Leverage multiplier (1-10)
- `is-long`: True for long position, false for short

**Returns:** Position ID

#### `close-position (position-id uint)`
Close an existing position and realize PnL.

**Parameters:**
- `position-id`: ID of the position to close

**Returns:** Final amount returned to user

#### `update-price (new-price uint)` (Owner Only)
Update the Bitcoin price oracle.

**Parameters:**
- `new-price`: New Bitcoin price

#### `set-emergency-shutdown` (Owner Only)
Activate emergency shutdown mode to pause new operations.

#### `withdraw-fees` (Owner Only)
Withdraw collected trading fees.

### Read-Only Functions

#### `get-position (position-id uint)`
Retrieve position details by ID.

#### `get-liquidity-balance (user principal)`
Get user's liquidity token balance.

#### `get-user-positions (user principal)`
Get list of user's position IDs.

#### `get-pool-stats`
Get current pool statistics including reserves and oracle price.

#### `get-contract-state`
Get contract owner and operational state.

#### `get-position-health (position-id uint)`
Calculate position health ratio for liquidation monitoring.

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy the contract:
```clarity
::deploy_contracts
```

3. Test contract functions:
```clarity
(contract-call? .BTCPerpetuals get-pool-stats)
```

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`

2. Deploy to testnet:
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`

2. Deploy to mainnet:
```bash
clarinet deployments generate --mainnet
clarinet deployments apply --mainnet
```

## Security Notes

### Risk Factors

- **Smart Contract Risk**: As with all DeFi protocols, smart contract bugs could result in loss of funds
- **Oracle Risk**: Price oracle failures could affect position liquidations and valuations
- **Liquidation Risk**: Leveraged positions may be liquidated if collateral falls below threshold
- **Market Risk**: Cryptocurrency price volatility affects position profitability

### Security Features

- **Owner Controls**: Emergency shutdown mechanism for critical situations
- **Position Limits**: Maximum leverage capped at 10x to limit systemic risk
- **Health Monitoring**: Position health ratios track liquidation risk
- **Fee Protection**: Trading fees ensure protocol sustainability
- **Timestamp Validation**: Oracle price staleness checks prevent manipulation

### Best Practices

- Always monitor position health ratios
- Use appropriate position sizing relative to your risk tolerance
- Understand liquidation mechanics before opening leveraged positions
- Keep emergency reserves for position management
- Regularly update and monitor oracle price feeds

## Error Codes

- `u100`: Owner-only function called by non-owner
- `u101`: Unauthorized access or operation not permitted
- `u102`: Invalid amount (zero or negative values)
- `u103`: Insufficient balance for operation
- `u104`: Insufficient liquidity in pool
- `u105`: Position not found
- `u106`: Position underwater (liquidatable)
- `u107`: Invalid leverage (outside 1-10x range)
- `u108`: Oracle price too old or invalid

## Testing

Run the test suite to verify contract functionality:

```bash
# Run all tests
npm test

# Run tests with coverage report
npm run test:report

# Watch mode for development
npm run test:watch
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the ISC License.

## Disclaimer

This software is provided "as is" without warranty. Users should understand the risks involved in DeFi protocols and perpetual futures trading. Only use funds you can afford to lose. This is experimental software and has not been audited by third parties.