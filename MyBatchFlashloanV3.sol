// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.10;


import {
  IPoolAddressesProvider
} from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPool.sol";
import { IFlashLoanReceiver } from "https://github.com/aave/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanReceiver.sol";
import { IERC20 } from "https://github.com/aave/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { IFaucet } from "https://github.com/aave/aave-v3-periphery/contracts/mocks/testnet-helpers/IFaucet.sol";

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  IPool public immutable override POOL;
  IFaucet public immutable FAUCET;

  constructor(IPoolAddressesProvider provider, IFaucet faucet) {
    ADDRESSES_PROVIDER = provider;
    POOL = IPool(provider.getPool());
    FAUCET = faucet;
  }
}

contract MyBatchFlashLoanV3 is FlashLoanReceiverBase {
    constructor(IPoolAddressesProvider _poolAddressesProvider, IFaucet _faucet) FlashLoanReceiverBase(_poolAddressesProvider, _faucet) {}

    // Modifier to restrict access to the Pool
    modifier onlyPool() {
        require(msg.sender == address(POOL), "Caller is not the Pool");
        _;
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
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
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwed = amounts[i] + premiums[i];
            FAUCET.mint(assets[i], address(this), premiums[i]);
            IERC20(assets[i]).approve(address(POOL), amountOwed);
        }

        return true;
    }

    function executeFlashLoan(
        address[] memory underlyingTokens,
        uint256[] memory amounts
    ) public {
        address receiverAddress = address(this);

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoan(
            receiverAddress,
            underlyingTokens,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }
}