// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;


import {
  ILendingPoolAddressesProvider
} from 'https://github.com/aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol';
import { ILendingPool } from 'https://github.com/aave/protocol-v2/contracts/interfaces/ILendingPool.sol';
import { IFlashLoanReceiver } from 'https://github.com/aave/protocol-v2/contracts/flashloan/interfaces/IFlashLoanReceiver.sol';
import { IERC20 } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import { IERC20Detailed } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import { SafeERC20 } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol';
import { SafeMath } from 'https://github.com/aave/protocol-v2/contracts/dependencies/openzeppelin/contracts/SafeMath.sol';
import { DataTypes } from 'https://github.com/aave/protocol-v2/contracts/protocol/libraries/types/DataTypes.sol';
import { ReserveConfiguration } from 'https://github.com/aave/protocol-v2/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';

/**
 * @dev Used to mint tokens from Aave faucets to cover flashloan fee, for testnet development only
 */
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

/**
 * @author DeFiSpartan
 * @title Aave flashloan starter kit for testnet development
 * @notice Never keep funds permanently on your FlashLoanReceiverBase contract as they could be exposed to a 'griefing' attack, where the stored funds are used by an attacker.
 */
contract MyBatchFlashLoanV2 is FlashLoanReceiverBase {
    using SafeMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    struct AvailableReserve {
        address underlyingAsset;
        string symbol;
        uint256 decimals;
        bool borrowingEnabled;
        bool stableBorrowRateEnabled;
        uint256 availableLiquidity;
        uint256 faucetAvailableLiquidty;
    }

    constructor(ILendingPoolAddressesProvider _addressProvider, IFaucet _faucet) FlashLoanReceiverBase(_addressProvider, _faucet) public {}
    
    /**
     * @notice Flashloan receiver, not called directly
     * @return `true` if transaction is succesful
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

        // To repay flashloan, approve the LendingPool contract to *pull* the owed amount, no transfer required
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            FAUCET.mint(assets[i],premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    /**
     * @notice Helper function to return all assets in the LendingPool
     * @return Array of available assets
     */
    function getAvailableAssets() 
      public
      view
      returns (address[] memory)
    {
        ILendingPool lendingPool = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());
        return lendingPool.getReservesList();
    }

    /**
     * @notice Helper function to return relavent fields about an asset for flashloan transactions 
     * @return AvailableReserve struct 
     */
    function getReserveData(address asset)
      public
      view
      returns (AvailableReserve memory)
    {
      ILendingPool lendingPool = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());
      AvailableReserve memory reserveData;
      reserveData.underlyingAsset = asset;
      DataTypes.ReserveData memory baseData =
        lendingPool.getReserveData(reserveData.underlyingAsset);

      reserveData.availableLiquidity = IERC20Detailed(reserveData.underlyingAsset).balanceOf(
        baseData.aTokenAddress
      );
      
      reserveData.symbol = IERC20Detailed(reserveData.underlyingAsset).symbol();
      reserveData.decimals = IERC20Detailed(reserveData.underlyingAsset).decimals();
      bool isActive;
      bool isFrozen;
      (
        isActive,
        isFrozen,
        reserveData.borrowingEnabled,
        reserveData.stableBorrowRateEnabled
      ) = baseData.configuration.getFlagsMemory();

      reserveData.faucetAvailableLiquidty = type(uint256).max - IERC20(reserveData.underlyingAsset).totalSupply();

      if(!isActive || isFrozen || !reserveData.borrowingEnabled){
        reserveData.availableLiquidity = 0;
      }

      return reserveData;
  }


    /**
     * @notice Alternate entry point, flashloans maximum amount of each asset
     */
    function executeMaxFlashLoan(
        address[] memory assets
    ) public {
        uint256[] memory amounts = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
          address asset = assets[i];
          AvailableReserve memory reserveData = getReserveData(asset);
          amounts[i] = reserveData.availableLiquidity <= reserveData.faucetAvailableLiquidty ? reserveData.availableLiquidity : reserveData.faucetAvailableLiquidty;
        }
        
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

    /**
     * @notice Generic entry point, specify assets and amounts to flashloan
     */
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