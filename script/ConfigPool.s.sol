// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract PoolConfigScript is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outboundRateLimiterIsEnabled,
        uint128 outboundRateLimiterCapacity,
        uint128 outboundRaTeLimiterRate,
        bool inboundRateLimiterisEnabled,
        uint128 inboundRateLimiterCapacity,
        uint128 inboundRateLimiterRate
    ) public {
        vm.startBroadcast();
        bytes[] memory remotePoolAddresses = new bytes[](1);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outboundRateLimiterIsEnabled,
                capacity: outboundRateLimiterCapacity,
                rate: outboundRaTeLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inboundRateLimiterisEnabled,
                capacity: inboundRateLimiterCapacity,
                rate: inboundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
        vm.stopBroadcast();
    }
}
