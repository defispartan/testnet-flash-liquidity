// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;


import {
  IPoolAddressesProvider
} from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPool.sol";
import { IFlashLoanSimpleReceiver } from "https://github.com/aave/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import { IERC20 } from "https://github.com/aave/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { IFaucet } from "https://github.com/aave/aave-v3-periphery/contracts/mocks/testnet-helpers/IFaucet.sol";

abstract contract FlashLoanSimpleReceiverBase is IFlashLoanSimpleReceiver {
  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  IPool public immutable override POOL;
  IFaucet public immutable FAUCET;

  constructor(IPoolAddressesProvider provider, IFaucet faucet) {
    ADDRESSES_PROVIDER = provider;
    POOL = IPool(provider.getPool());
    FAUCET = faucet;
  }
}

contract MySimpleFlashLoanV3 is FlashLoanSimpleReceiverBase {
    constructor(IPoolAddressesProvider _poolAddressProvider, IFaucet _faucet) FlashLoanSimpleReceiverBase(_poolAddressProvider, _faucet) {}

    // Modifier to restrict access to the Pool
    modifier onlyPool() {
        require(msg.sender == address(POOL), "Caller is not the Pool");
        _;
    }

    /**
        This function is called after your contract has received the borrowed amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    )
        external
        override
        onlyPool
        returns (bool)
    {

        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //

        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.

        // Approve the Pool contract allowance to *pull* the owed amount
        uint amountOwed = amount + premium;
        FAUCET.mint(asset, address(this), premium);
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    function executeFlashLoan(
        address underlyingToken,
        uint256 amount
    ) public {
        address receiverAddress = address(this);

        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            underlyingToken,
            amount,
            params,
            referralCode
        );
    }
}