# Hack Money Flash Liquidity Demo

This is a starter contract for accessing flash liquidity from Aave V3 testnet markets, there are two variants: simple (for borrowing a single asset) and batch (multiple assets). These contracts use the Aave Faucet to cover the 0.07% fee, simplifying the process of running your first transaction. Once you've added and tested your logic on testnet, you'll need to remove the references to the FAUCET from your contract before deploying to mainnet.

## Steps

- 1.) Open contract in remix:
    - [Batch](https://remix.ethereum.org/#url=https://github.com/defispartan/hackmoney-demo/blob/main/MyBatchFlashloanV3.sol) 
    - [Simple](https://remix.ethereum.org/#url=https://github.com/defispartan/hackmoney-demo/blob/main/MySimpleFlashloanV3.sol)
- 2.) Deploy to any network, passing in the addresses below to the constructor
- 3.) Pick an asset and amount \*
- 4.) Call `executeFlashloan` with parameters from step 3

\* To get the asset address and available amount, go to the overview page for the reserve you want to borrow:

![Aave Reserve Data](AssetParameters.PNG)

- asset address is: `A`
- max amount available to borrow is: `B` / `C` \* (10^`D`)

Note: If an asset has a debtCeiling, the max amount available to borrow will be min(`totalBorrowed` - `debtCeiling`, `availableLiquidity`)

## Contract Addresses

### PoolAddressesProvider

- Eth Rinkeby V3: 0xBA6378f1c1D046e9EB0F538560BA7558546edF3C
- Mumbai V3: 0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6
- Fuji V3: 0x1775ECC8362dB6CaB0c7A9C0957cF656A5276c29
- Arbitrum Rinkeby V3: 0xF7158D1412Bdc8EAfc6BF97DB4e2178379c9521c
- Optimistic Kovan V3: 0xD15d36975A0200D11B8a8964F4F267982D2a1cFe
- Fantom Testnet V3: 0xE339D30cBa24C70dCCb82B234589E3C83249e658
- Harmony Testnet V3: 0xd19443202328A66875a51560c28276868B8C61C2

### Aave Faucets

- Eth Rinkeby V3: 0x88138CA1e9E485A1E688b030F85Bb79d63f156BA
- Mumbai V3: 0xc1eB89DA925cc2Ae8B36818d26E12DDF8F8601b0
- Fuji V3: 0x127277bF2F5fA186bfC6b3a0ca00baefB5472d3a
- Arbitrum Rinkeby V3: 0x3BE25d21ee1C417462E97CEF1D53da9011149384
- Optimistic Kovan V3: 0xed97140B58B97FaF70b70Ae26714Aa59705c74aE
- Fantom Testnet V3: 0x02D538e56A729C535F83b2DA20Ddf9AD7281FE6c
- Harmony Testnet V3: 0x8f57153F18b7273f9A814b93b31Cb3f9b035e7C2
