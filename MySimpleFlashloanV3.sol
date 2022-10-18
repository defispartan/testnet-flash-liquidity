// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;


import {
  IPoolAddressesProvider
} from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "https://github.com/aave/aave-v3-core/contracts/interfaces/IPool.sol";
import { IFlashLoanSimpleReceiver } from "https://github.com/aave/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import { IERC20 } from "https://github.com/aave/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { IERC20Detailed } from 'https://github.com/aave/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import { SafeMath } from "https://github.com/aave/aave-v3-core/contracts/dependencies/openzeppelin/contracts/SafeMath.sol";
import { DataTypes } from 'https://github.com/aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol';
import { ReserveConfiguration } from 'https://github.com/aave/aave-v3-core/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import { MathUtils } from 'https://github.com/aave/aave-v3-core/contracts/protocol/libraries/math/MathUtils.sol';
import { WadRayMath} from 'https://github.com/aave/aave-v3-core/contracts/protocol/libraries/math/WadRayMath.sol';
import { PercentageMath} from 'https://github.com/aave/aave-v3-core/contracts/protocol/libraries/math/PercentageMath.sol';
import { IVariableDebtToken } from 'https://github.com/aave/aave-v3-core/contracts/interfaces/IVariableDebtToken.sol';
import { IStableDebtToken } from 'https://github.com/aave/aave-v3-core/contracts/interfaces/IStableDebtToken.sol';
/**
 * @dev Used to mint tokens from Aave faucets to cover flashloan fee, for testnet development only
 */
interface IFaucet {
    function mint(
        address _token,
        uint256 _amount
    ) external;
}

abstract contract FlashLoanSimpleReceiverBase is IFlashLoanSimpleReceiver {
  using SafeMath for uint256;

  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  IPool public immutable override POOL;
  IFaucet public immutable FAUCET;

  constructor(IPoolAddressesProvider provider, IFaucet faucet) {
    ADDRESSES_PROVIDER = provider;
    POOL = IPool(provider.getPool());
    FAUCET = faucet;
  }
}


/**
 * @author DeFiSpartan
 * @title Aave flashloan starter kit for testnet development
 * @notice Never keep funds permanently on your FlashLoanReceiverBase contract as they could be exposed to a 'griefing' attack, where the stored funds are used by an attacker.
 */
contract MySimpleFlashLoanV3 is FlashLoanSimpleReceiverBase {
    using SafeMath for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    struct AvailableReserve {
        address underlyingAsset;
        string symbol;
        uint256 decimals;
        bool borrowingEnabled;
        bool stableBorrowRateEnabled;
        bool isActive;
        bool isFrozen;
        uint256 borrowCap;
        uint256 remainingBorrowCap;
        bool isPaused;
        uint256 faucetAvailableLiquidty;
        uint256 availableLiquidity;
    }

    constructor(IPoolAddressesProvider _addressProvider, IFaucet _faucet) FlashLoanSimpleReceiverBase(_addressProvider, _faucet) {}

    /**
     * @notice Flashloan receiver, not called directly
     * @return `true` if transaction is succesful
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
        uint amountOwed = amount.add(premium);
        FAUCET.mint(asset,premium);
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    /**
     * @notice Helper function to return all assets in the Pool
     * @return array of available assets
     */
    function getAvailableAssets() 
      public
      view
      returns (address[] memory)
    {
        IPool pool = IPool(ADDRESSES_PROVIDER.getPool());
        return pool.getReservesList();
    }

    /**
     * @notice Helper function to return relavent fields about an asset for flashloan transactions 
     * @param asset Underlying asset to fetch reserve data for
     * @return AvailableReserve struct of asset data
     */
    function getReserveData(address asset)
      public
      view
      returns (AvailableReserve memory)
    {
      IPool pool = IPool(ADDRESSES_PROVIDER.getPool());
      AvailableReserve memory reserveData;
      reserveData.underlyingAsset = asset;
      DataTypes.ReserveData memory baseData =
        pool.getReserveData(reserveData.underlyingAsset);

      reserveData.availableLiquidity = IERC20Detailed(reserveData.underlyingAsset).balanceOf(
        baseData.aTokenAddress
      );
      
      reserveData.symbol = IERC20Detailed(reserveData.underlyingAsset).symbol();
      reserveData.decimals = IERC20Detailed(reserveData.underlyingAsset).decimals();
      (
        reserveData.isActive,
        reserveData.isFrozen,
        reserveData.borrowingEnabled,
        reserveData.stableBorrowRateEnabled,
        reserveData.isPaused
      ) = baseData.configuration.getFlags();
      (
        reserveData.borrowCap,
      ) = baseData.configuration.getCaps();
      reserveData.remainingBorrowCap = type(uint256).max;
      reserveData.faucetAvailableLiquidty = type(uint256).max - IERC20(reserveData.underlyingAsset).totalSupply();
      if(!reserveData.isActive || reserveData.isFrozen || !reserveData.borrowingEnabled || reserveData.isPaused){
        reserveData.availableLiquidity = 0;
      } else if (reserveData.borrowCap != 0) {
        uint256 totalPrincipalStableDebt = 0;
        uint256 averageStableRate = 0;
        uint256 stableDebtLastUpdateTimestamp = 0;
        uint256 totalScaledVariableDebt = 0;
              (
        totalPrincipalStableDebt,
        ,
        averageStableRate,
        stableDebtLastUpdateTimestamp
      ) = IStableDebtToken(baseData.stableDebtTokenAddress).getSupplyData();
        totalScaledVariableDebt = IVariableDebtToken(baseData.variableDebtTokenAddress)
        .scaledTotalSupply();
        
        uint256 cumulatedStableInterest = MathUtils.calculateCompoundedInterest(
      averageStableRate,
      stableDebtLastUpdateTimestamp,
      baseData.lastUpdateTimestamp
    );
        uint256 totalBorrows = totalScaledVariableDebt.rayMul(baseData.variableBorrowIndex) + totalPrincipalStableDebt.rayMul(cumulatedStableInterest);
        
        reserveData.remainingBorrowCap = totalBorrows - reserveData.borrowCap;
        reserveData.availableLiquidity = reserveData.availableLiquidity <= reserveData.remainingBorrowCap ? reserveData.availableLiquidity : reserveData.remainingBorrowCap;
      }

      return reserveData;
  }

    /**
     * @notice Generic entry point, specify assets and amounts to flashloan
     * @param asset underlying asset address to flashloan
     * @param amount amount to borrow in the flashloan transaction
     */
    function executeFlashLoan(
        address asset,
        uint256 amount
    ) public {
        address receiverAddress = address(this);

        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

     /**
     * @notice Alternate entry point, flashloans maximum amount of asset
     * @param asset underlying asset address to flashloan
     */
    function executeMaxFlashLoan(
        address asset
    ) public {
        AvailableReserve memory reserveData = getReserveData(asset);
        uint256 amount = reserveData.availableLiquidity <= reserveData.faucetAvailableLiquidty ? reserveData.availableLiquidity : reserveData.faucetAvailableLiquidty;
        
        address receiverAddress = address(this);

        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }
}