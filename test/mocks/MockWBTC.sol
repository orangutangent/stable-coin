// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {MintableERC20} from "./MintableERC20.sol";

contract MockWBTC is MintableERC20 {
    constructor() MintableERC20("Wrapped Bitcoin", "WBTC", 8) {}
}
