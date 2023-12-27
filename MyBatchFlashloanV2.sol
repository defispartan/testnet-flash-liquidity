// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;


import {
  ILendingPoolAddressesProvider
} from 'https://github.com/aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol';
import { ILendingPool } from 'https://github.com/aave/protocol-v2/contracts/interfaces/ILendingPool.sol';
import { IFlashLoanReceiver } from 'https://github.com/aave/protocol-v2/contracts/flashloan/interfaces/IFlashLoanReceiver.sol';
import { IERC20 } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import { SafeERC20 } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';
import { SafeMath } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/SafeMath.sol';

interface IFaucet {
    function mint(
        address _token,
        uint256 _amount
    ) external;
}

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  ILendingPool public immutable override LENDING_POOL;
  IFaucet public immutable FAUCET;

  constructor(ILendingPoolAddressesProvider provider, IFaucet faucet) public {
    ADDRESSES_PROVIDER = provider;
    LENDING_POOL = ILendingPool(provider.getLendingPool());
    FAUCET = faucet;
  }
}

contract MyBatchFlashLoanV2 is FlashLoanReceiverBase {
    using SafeMath for uint256;

    constructor(ILendingPoolAddressesProvider _addressProvider, IFaucet _faucet) FlashLoanReceiverBase(_addressProvider, _faucet) public {}

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

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            FAUCET.mint(assets[i],premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    function executeFlashLoan(
        address[] memory assets,
        uint256[] memory amounts
    ) public {
        address receiverAddress = address(this);

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }
}