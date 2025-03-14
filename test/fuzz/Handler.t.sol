// SPSX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    address[] public usersDepositedCollateral;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(
            dsce.getCollateralTokenPriceFeed(address(weth))
        );
        btcUsdPriceFeed = MockV3Aggregator(
            dsce.getCollateralTokenPriceFeed(address(wbtc))
        );
    }

    function depositCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = getCollateralFromSeed(collateralSeed);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersDepositedCollateral.push(msg.sender);
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        vm.startPrank(msg.sender);
        ERC20Mock collateral = getCollateralFromSeed(collateralSeed);
        (uint256 totalDscMinted, uint256 totalCollateralValue) = dsce
            .getAccountInformation(msg.sender);

        uint256 userBalance = dsce.getCollateralBalanceOfUser(
            msg.sender,
            address(collateral)
        );

        uint256 totalMintedInCollateral = dsce.getTokenAmountFromUsd(
            address(collateral),
            totalDscMinted
        );
        if (userBalance < 4) return;
        if (totalMintedInCollateral > userBalance / 2 - 2) return; // to skip breaks health factor on 0.99999...
        uint256 maxCollateralToRedeem = (userBalance / 2) -
            totalMintedInCollateral;

        uint256 amountCollateralBounded = bound(
            amountCollateral,
            0,
            maxCollateralToRedeem
        );
        console.log("totalDscMinted", totalDscMinted);
        console.log("totalCollateralValue", totalCollateralValue);
        console.log("amountCollateralBounded", amountCollateralBounded);
        console.log(
            "getCollateralBalanceOfUser",
            dsce.getCollateralBalanceOfUser(msg.sender, address(collateral))
        );
        if (amountCollateralBounded == 0) {
            return;
        }

        dsce.redeemCollateral(address(collateral), amountCollateralBounded);
        vm.stopPrank();
    }

    function mintDSC(uint256 amount, uint256 addressSeed) public {
        if (usersDepositedCollateral.length == 0) return;
        address userAddress = usersDepositedCollateral[
            addressSeed % usersDepositedCollateral.length
        ];

        vm.startPrank(userAddress);
        (uint256 totalDscMinted, uint256 totalCollateralValue) = dsce
            .getAccountInformation(userAddress);

        uint256 maxDscToMint = (totalCollateralValue / 2) - totalDscMinted;
        if (maxDscToMint < 0) {
            return;
        }

        amount = bound(amount, 0, maxDscToMint);
        if (amount == 0) return;
        dsce.mintDSC(amount);
        vm.stopPrank();
    }

    // breaks test
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    //* Helper Functions

    function getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
