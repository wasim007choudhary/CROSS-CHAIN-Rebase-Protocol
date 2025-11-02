// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CCRVault} from "../src/CCRTvault.sol";
import {ICCRebaseToken} from "../src/Interface/ICCRebaseToken.sol";
import {CCRToken} from "../src/CCRebaseToken.sol";
import {CCRebaseTokenPool} from "../src/CCRebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from
    "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract DeployTokenAndPool is Script {
    function run() public returns (CCRToken ccrToken, CCRebaseTokenPool ccrtPool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        // Step 1: Deploy token + pool as default deployer
        vm.startBroadcast();
        ccrToken = new CCRToken();
        ccrtPool = new CCRebaseTokenPool(
            IERC20(address(ccrToken)), new address, networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        ICCRebaseToken(ccrToken).grantMintAndBurnRoleAccess(address(ccrtPool));
        vm.stopBroadcast();

        // Step 2: Switch to token owner for registry configuration
        address tokenOwner = ccrToken.owner();
        vm.startBroadcast(tokenOwner);

        // Register token under admin registry
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(ccrToken)
        );

        // Accept admin role and assign pool
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(ccrToken));

        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(address(ccrToken), address(ccrtPool));

        vm.stopBroadcast();
    }
}

contract DeployVault is Script {
    function run(address ccrToken) public returns (CCRVault vault) {
        vm.startBroadcast();
        vault = new CCRVault(ICCRebaseToken(ccrToken));
        ICCRebaseToken(ccrToken).grantMintAndBurnRoleAccess(address(vault));
        vm.stopBroadcast();
    }
}
