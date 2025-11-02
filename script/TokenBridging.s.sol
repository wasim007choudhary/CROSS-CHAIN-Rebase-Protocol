// SPDX-License-Identifier- MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract TokenBridgingScript is Script {
    function run(
        address receiverAddress,
        uint64 destChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address ccipRouterAddress
    ) public {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: tokenToSendAddress, amount: amountToSend});
        vm.startBroadcast();
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        uint256 ccipFee = IRouterClient(ccipRouterAddress).getFee(destChainSelector, message);
        IERC20(linkTokenAddress).approve(ccipRouterAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(ccipRouterAddress, amountToSend);

        IRouterClient(ccipRouterAddress).ccipSend(destChainSelector, message);
        vm.stopBroadcast();
    }
}
