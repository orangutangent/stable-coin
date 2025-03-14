//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (, , weth, wbtc, ) = config.activeNetworkConfig();
        // targetContract(address(dscEngine));
        Handler handler = new Handler(dscEngine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDepositerd = ERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDepositerd = ERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDepositerd);
        uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDepositerd);

        console2.log("weth value: ", weth);
        console2.log("wbtc value: ", wbtc);
        console2.log("totalSupply: ", totalSupply);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    // function invariant_gettersShouldNotRevert() public view {
    //     dscEngine.getAccountCollateralValue(msg.sender);
    //     dscEngine.getAccountInformation(msg.sender);
    //     dscEngine.getAdditionalFeedPrecision();
    //     dscEngine.getCollateralBalanceOfUser(msg.sender, msg.sender);
    //     dscEngine.getCollateralTokenPriceFeed(msg.sender);
    //     dscEngine.getCollateralTokens();
    //     dscEngine.getDsc();
    //     dscEngine.getHealthFactor(msg.sender);
    //     dscEngine.getLiquidationBonus();
    //     dscEngine.getLiquidationPrecision();
    //     dscEngine.getLiquidationThreshold();
    //     dscEngine.getMinHealthFactor();
    //     dscEngine.getPrecision();
    //     dscEngine.getTokenAmountFromUsd(msg.sender, 1234);
    //     dscEngine.getUsdValue(msg.sender, 12324);
    // }
}
