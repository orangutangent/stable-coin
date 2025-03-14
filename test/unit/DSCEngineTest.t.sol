// SPDX-Liciense identifier: MIT

pragma solidity ^0.8.19;


import {Test,console} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";


contract DSCEngineTest is Test {
    DecentralizedStableCoin public  dsc;
    DSCEngine public  dscEngine;
    HelperConfig  public  config;
    address public weth;
    address public ethPriceFeed;
    address public wbtcUsdPriceFeed;
    address public USER = makeAddr("user");
    address public OTHER_USER = makeAddr("otherUser");

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL2 = 100 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;


    function setUp() public {
        DeployDSC deployer = new DeployDSC();
        (dsc,dscEngine, config) = deployer.run();
        (ethPriceFeed,wbtcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        if (block.chainid == 31337){
            ERC20Mock(weth).mint(USER,AMOUNT_COLLATERAL);
            ERC20Mock(weth).mint(OTHER_USER,AMOUNT_COLLATERAL2);
        }

    }

    //* Constructor test

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesNotMAtchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses,address(dsc));


    }     

    //* Price tests

    function testGetUsdValue() public  {
        uint256 ethAmount = 1e18;
        uint256 expectedUsd = 2000e18;
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);
        assert(expectedUsd == actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth,usdAmount);

        assert(expectedWeth == actualWeth);
    }


    //* Deposit collateral test

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth,0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER,AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.depositCollateral(address(ranToken),AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        console.log("depositing collateral");
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth,AMOUNT_COLLATERAL);
        vm.stopPrank(); 
        _;
    }
    modifier depositedCollateralAndMintDsc() {
        console.log("depositing collateral");
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth,AMOUNT_COLLATERAL);

          uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL)*dscEngine.getLiquidationThreshold()/dscEngine.getLiquidationPrecision();

        dscEngine.mintDSC(amountDsc);
        vm.stopPrank(); 
        _;
    }

    modifier depositedCollateral2() {
        console.log("depositing collateral 2");
        vm.startPrank(OTHER_USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth,AMOUNT_COLLATERAL);

      
        vm.stopPrank(); 
        _;
    }
    modifier depositedCollateralAndMintDsc2() {
        console.log("depositing collateral 2");
        vm.startPrank(OTHER_USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL2);
        dscEngine.depositCollateral(weth,AMOUNT_COLLATERAL2);

        uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL)*dscEngine.getLiquidationThreshold()/dscEngine.getLiquidationPrecision();

        dscEngine.mintDSC(amountDsc);
        vm.stopPrank(); 
        _;
    }

    function testDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);

        uint256 expectedTotalDscMined = 0;
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assert(expectedTotalDscMined == totalDscMinted);
        assert(expectedDepositAmount == AMOUNT_COLLATERAL);
    }

    function testDepositCollateralAndMintDSC() public  {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL)*dscEngine.getLiquidationThreshold()/dscEngine.getLiquidationPrecision();
        dscEngine.depositCollateralAndMintDSC(weth,AMOUNT_COLLATERAL,amountDsc);

        (uint256 totalDscMinted, uint256 collateralValueInUsd)  = dscEngine.getAccountInformation(USER);
        vm.stopPrank(); 

        assert(amountDsc == totalDscMinted);
        assert(collateralValueInUsd == totalDscMinted*dscEngine.getLiquidationPrecision()/dscEngine.getLiquidationThreshold());

    }

    function testDepositCollateralAndMintDSCRevertsIfBreeakHealthFactor() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL);

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__BreaksHealthFactor.selector,
                0.5 ether  // 0.5 health factor
            )
        );
        dscEngine.depositCollateralAndMintDSC(weth,AMOUNT_COLLATERAL,amountDsc);

        vm.stopPrank(); 

    }

    // * Redeem collateral test

    function testRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
  
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        (, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        vm.stopPrank();

        assert(ERC20Mock(weth).balanceOf(USER)==AMOUNT_COLLATERAL);
        assert(collateralValueInUsd==0);

    }

    function testRedeemCollateralForDSC() public depositedCollateral {
        vm.startPrank(USER);

        uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL)*dscEngine.getLiquidationThreshold()/dscEngine.getLiquidationPrecision();

        dscEngine.mintDSC(amountDsc);

        ERC20(dsc).approve(address(dscEngine),amountDsc);

        dscEngine.redeemCollateralForDSC(weth, AMOUNT_COLLATERAL,amountDsc);
        (, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        vm.stopPrank();

        assert(ERC20Mock(weth).balanceOf(USER)==AMOUNT_COLLATERAL);
        assert(collateralValueInUsd==0);
    }


    // * test liquidate

    function testRevertIfHealthOK() public depositedCollateral {
        vm.startPrank(OTHER_USER);

        vm.expectRevert(DSCEngine.DSCEngine__HeathFactorOK.selector);
        dscEngine.liquidate(weth, USER,1 ether);
        vm.stopPrank();
    }


    function testCanLiquidate() public depositedCollateralAndMintDsc depositedCollateralAndMintDsc2 {

        vm.startPrank(OTHER_USER);

        uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL)*(dscEngine.getLiquidationThreshold())/dscEngine.getLiquidationPrecision();


        ERC20(dsc).approve(address(dscEngine),amountDsc);

        MockV3Aggregator(ethPriceFeed).updateAnswer(1800e8);
        (, uint256 collateralValueInUsdBefore) = dscEngine.getAccountInformation(USER);
        uint256 balanceBefore = ERC20Mock(weth).balanceOf(OTHER_USER);
        
        dscEngine.liquidate(weth, USER,amountDsc);

        (uint256 totalDscMintedAfter, uint256 collateralValueInUsdAfter) = dscEngine.getAccountInformation(USER);

        uint256 balanceAfter = ERC20Mock(weth).balanceOf(OTHER_USER);
    
        vm.stopPrank();

        assertEq(totalDscMintedAfter, 0);
        assert(balanceAfter>balanceBefore);
        assert(collateralValueInUsdBefore>collateralValueInUsdAfter);
    }

    function testCanBurnDsc() public depositedCollateralAndMintDsc {
        vm.startPrank(USER);
        uint256 amountDsc = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL)*dscEngine.getLiquidationThreshold()/dscEngine.getLiquidationPrecision();

        ERC20(dsc).approve(address(dscEngine),amountDsc);

        dscEngine.burnDSC(amountDsc);

        (uint256 totalDscMinted, ) = dscEngine.getAccountInformation(USER);

        vm.stopPrank();

        assertEq(totalDscMinted,0);

    }

}