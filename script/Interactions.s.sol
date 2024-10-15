// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @title Interactions
 * @author Abhinav Pangaria
 * @notice Contains contracts and functions to communicate and work with the Raffle, giving it more functionality.
 * @dev - Using LINK token to fund the subscription.
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() internal returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address vrfCoordinator = config.vrfCoordinatorV2_5;
        address account = config.account;

        // create subscription

        uint256 subId = createSubscription(vrfCoordinator, account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address _vrfCoordinator, address account) public returns (uint256 subId) {
        console2.log("Creating Subscription on chainId ", block.chainid);
        console2.log("Creating using coordinator: ", _vrfCoordinator);

        vm.startBroadcast(account);
        subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console2.log("Subscription created with id: ", subId);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 private constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;

        fundSubscription(subscriptionId, vrfCoordinator, linkToken, account);
    }

    function fundSubscription(uint256 subscriptionId, address vrfCoordinator, address linkToken, address account)
        public
    {
        console2.log("Fund Subscription with subscriptionId ", subscriptionId);
        if (block.chainid == ETH_LOCAL_CHAIN_ID) {
            console2.log("Funding for local chainId: ", block.chainid);
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 1000 // because our local mock is very expensive so either to make that cheap or increase here.
            );
            vm.stopBroadcast();
        } else {
            console2.log("Funding for chainId: ", block.chainid);
            console2.log(LinkToken(linkToken).balanceOf(msg.sender));
            console2.log(msg.sender);
            console2.log(LinkToken(linkToken).balanceOf(address(this)));
            console2.log(address(this));

            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }

        console2.log("Subscription funded with amount: ", FUND_AMOUNT);
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV2_5 = helperConfig.getConfig().vrfCoordinatorV2_5;
        address account = helperConfig.getConfig().account;

        addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console2.log("Adding consumer contract: ", contractToAddToVrf);
        console2.log("Using vrfCoordinator: ", vrfCoordinator);
        console2.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
