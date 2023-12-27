# Testnet Flash Liquidity Demo

Template smart contracts for accessing flash liquidity from Aave V3 testnet markets. Two variants: simple (borrowing a single token) and batch (multiple tokens).

These templates utilize faucet of Aave testnet markets to mint flashloan premium, allowing an address to call `executeFlashloan` and execute a simple borrow and return transaction.

Notes:

- Aave V3 faucets have a per-txn limit of 10000 (in underlying token decimals)
- [BGD Labs Address Registry](https://github.com/bgd-labs/aave-address-book/) contains `PoolAddressesProvider`, `Faucet`, and underlying reserve token addresses
- It's recommended to add access modifiers (e.g. onlyOwner) to any public facing functions to prevent griefing attacks, especially if funds are stored on contract
- For more instructions on deploying a contract in Remix, check out this [awesome guide](https://docs.chain.link/docs/deploy-your-first-contract/) from Chainlink

## Steps

- 1.) Open contract in remix:
  - [Batch](https://remix.ethereum.org/#url=https://github.com/defispartan/testnet-flash-liquidity/blob/main/MyBatchFlashloanV3.sol)
  - [Simple](https://remix.ethereum.org/#url=https://github.com/defispartan/testnet-flash-liquidity/blob/main/MySimpleFlashloanV3.sol)
- 2.) Complile and deploy to any network with Aave Protocol market, passing in the `PoolAddressesProvider` and `Faucet` for Aave market to the constructor, addresses [here](https://github.com/bgd-labs/aave-address-book/)
- 3.) Call `executeFlashloan` with `underlyingToken` and `amount` parameters, token addresses [here](https://github.com/bgd-labs/aave-address-book/),

\* To get the underlying token address and available amount, go to the overview page for the reserve you want to borrow:

![Aave Reserve Data](AssetParameters.PNG)

- underlying token address is: `A`
- max amount available to borrow is: `B` / `C` \* (10^`D`)

If an underlying token has a debtCeiling, the max amount available to borrow is min(`totalBorrowed` - `debtCeiling`, `availableLiquidity`).

Aave V3 testnet faucets which are used in templates have a per-tx mint limit of 10000 (in underlying token decimals).
