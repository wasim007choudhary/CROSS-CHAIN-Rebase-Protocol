// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CCRToken} from "../src/CCRebaseToken.sol";
import {CCRVault} from "../src/CCRTvault.sol";
import {ICCRebaseToken} from "../src/Interface/ICCRebaseToken.sol";
import {CCRebaseTokenPool} from "../src/CCRebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "lib/chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "lib/ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from
    " lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "lib/ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "lib/ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CCTest is Test {
    CCRToken sepoliaCCRToken;
    CCRToken arbSepoliaCCRToken;

    CCRVault vault;

    CCRebaseTokenPool sepoliaCCRTpool;
    CCRebaseTokenPool arbSepoliaCCRTpool;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    address public owner = makeAddr("owner");
    address user = makeAddr("user");
    uint256 constant SEND_AMOUNT = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    // RegistryModuleOwnerCustom sepoliaRegistryModuleOwnerCustom;
    // RegistryModuleOwnerCustom arbSepoliaRegistryModuleOwnerCustom;

    // TokenAdminRegistry sepoliaTokenAdminRegistry;
    // TokenAdminRegistry arbSepoliaTokenAdminRegistry;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);

        sepoliaCCRToken = new CCRToken();
        vault = new CCRVault(ICCRebaseToken(address(sepoliaCCRToken))); //No gonna deploy in the dest chain because we want deposit and redeem to be done in the source chain ! PERSONAL CHOICE THO!!
        sepoliaCCRTpool = new CCRebaseTokenPool(
            IERC20(address(sepoliaCCRToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaCCRToken.grantMintAndBurnRoleAccess(address(vault));
        sepoliaCCRToken.grantMintAndBurnRoleAccess(address(sepoliaCCRTpool));
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaCCRToken)
        );
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaCCRToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaCCRToken), address(sepoliaCCRTpool)
        );
        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startPrank(owner);

        arbSepoliaCCRToken = new CCRToken();
        arbSepoliaCCRTpool = new CCRebaseTokenPool(
            IERC20(address(arbSepoliaCCRToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaCCRToken.grantMintAndBurnRoleAccess(address(arbSepoliaCCRTpool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaCCRToken)
        );
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(
            address(arbSepoliaCCRToken)
        );
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaCCRToken), address(arbSepoliaCCRTpool)
        );
        vm.stopPrank();
        tokenPoolConfiguration(
            sepoliaFork,
            address(sepoliaCCRTpool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaCCRTpool),
            address(arbSepoliaCCRToken)
        );

        tokenPoolConfiguration(
            arbSepoliaFork,
            address(arbSepoliaCCRTpool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaCCRTpool),
            address(sepoliaCCRToken)
        );
    }

    function tokenPoolConfiguration(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        vm.prank(owner);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        CCRToken localToken,
        CCRToken remoteToken
    ) public {
        vm.selectFork(localFork);

        console.log("\n--- Bridging Tokens ---");
        console.log("Source Chain:", block.chainid);
        console.log("Amount to Bridge:", amountToBridge);
        console.log("User Local Balance Before:", localToken.balanceOf(user));

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 500_000, allowOutOfOrderExecution: false}))
        });
        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);

        console.log("Calculated LINK Fee:", fee);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 30 minutes);
        console.log("\n--- Receiving on Destination Chain ---");
        console.log("Destination Chain:", block.chainid);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);
    }

    function testBridgingTokensOneSided() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_AMOUNT);

        console.log("\n==== Test Start: Depositing on Sepolia ====");

        console.log("User ETH Before Deposit:", user.balance);
        vm.prank(user);
        CCRVault(payable(address(vault))).deposit{value: 1e4}();
        console.log("User CCRToken After Deposit:", sepoliaCCRToken.balanceOf(user));
        assertEq(user.balance, SEND_AMOUNT - sepoliaCCRToken.balanceOf(user));
        assertEq(sepoliaCCRToken.balanceOf(user), 1e4);

        console.log("\n==== Bridge From Sepolia -> Arbitrum Sepolia ====");
        uint256 bridgeAmount = 1e2;
        console.log("Amount brigding from source to destination -> ", bridgeAmount);
        bridgeTokens(
            bridgeAmount,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaCCRToken,
            arbSepoliaCCRToken
        );
        uint256 userArbSepoliaBalance = arbSepoliaCCRToken.balanceOf(user);
        assertEq(userArbSepoliaBalance, bridgeAmount);
    }

    function testBridgingAllTheTokensDestChainAndBackToTheSourceChaain() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_AMOUNT);
        console.log("\n==== Test Start: Deposit on Sepolia ====");
        console.log("User ETH Before Deposit:", user.balance);
        vm.prank(user);
        CCRVault(payable(address(vault))).deposit{value: SEND_AMOUNT}();
        console.log("User CCRToken After Deposit:", sepoliaCCRToken.balanceOf(user));
        assertEq(sepoliaCCRToken.balanceOf(user), SEND_AMOUNT);
        console.log("\n==== Bridge From Sepolia -> Arbitrum Sepolia ====");

        bridgeTokens(
            SEND_AMOUNT,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaCCRToken,
            arbSepoliaCCRToken
        );

        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 30 minutes);
        console.log("\n==== Bridge Back From Arbitrum Sepolia -> Sepolia ====");
        bridgeTokens(
            arbSepoliaCCRToken.balanceOf(user),
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaCCRToken,
            sepoliaCCRToken
        );
    }

    function testDoubleBrdiging() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_AMOUNT);
        vm.startPrank(user);
        CCRVault(payable(address(vault))).deposit{value: SEND_AMOUNT}();
        uint256 startingBalance = sepoliaCCRToken.balanceOf(user);
        assertEq(startingBalance, SEND_AMOUNT);
        vm.stopPrank();
        console.log("Source Chain Balance before bridge and time passed- ", startingBalance);
        console.log("First Bridge EVENT -> Bridging %d tokens ", SEND_AMOUNT / 2);
        bridgeTokens(
            SEND_AMOUNT / 2,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaCCRToken,
            arbSepoliaCCRToken
        );

        vm.selectFork(sepoliaFork);
        vm.warp(block.timestamp + 2 hours);
        uint256 sourceChainBalanceNow = sepoliaCCRToken.balanceOf(user);
        console.log("User Balance in source chain After Bridge and time passed - ", sourceChainBalanceNow);
        console.log("--- Second Bridge Event --- Bridging %d tokens ", sourceChainBalanceNow);

        bridgeTokens(
            sourceChainBalanceNow,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaCCRToken,
            arbSepoliaCCRToken
        );

        vm.selectFork(arbSepoliaFork);
        console.log("Balance Of the User Before time warp ", arbSepoliaCCRToken.balanceOf(user));
        vm.warp(block.timestamp + 3 hours);
        console.log("Balance of the User After Time Warp ", arbSepoliaCCRToken.balanceOf(user));
        uint256 destChainBalance = IERC20(address(arbSepoliaCCRToken)).balanceOf(user);
        console.log("Just a check - ", destChainBalance);
        assertEq(destChainBalance, arbSepoliaCCRToken.balanceOf(user));
        console.log("Bridging back %d tokens back to the source chain ", destChainBalance);
        bridgeTokens(
            destChainBalance,
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaCCRToken,
            sepoliaCCRToken
        );

        vm.selectFork(sepoliaFork);
        console.log("Now user balance in the source -- ", sepoliaCCRToken.balanceOf(user));
        assertEq(sepoliaCCRToken.balanceOf(user), destChainBalance);
    }
}
