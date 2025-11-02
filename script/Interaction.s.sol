// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CCRVault} from "../src/CCRTvault.sol";

contract Deposit is Script {
    // The constant Value i.e. be sent during deposits
    uint256 private constant SEND_AMOUNT = 0.01 ether;

    function depositFund(address vault) public payable {
        /**
         * @notice Deposits funds to the specified vault.
         * @param vault The address of the CCRVault contract.
         */
        CCRVault(payable(vault)).deposit{value: SEND_AMOUNT}();
    }

    /**
     * @notice Runs the deposit script.
     * @param vault The address of the CCRVault contract.
     */
    function run(address vault) external payable {
        depositFund(vault);
    }
}

contract Redeem is Script {
    function redeemFund(address vault) public {
        // Redeem the max balance
        CCRVault(payable(address(vault))).redeem(type(uint256).max);
    }

    function run(address vault) external {
        redeemFund(vault);
    }
}
