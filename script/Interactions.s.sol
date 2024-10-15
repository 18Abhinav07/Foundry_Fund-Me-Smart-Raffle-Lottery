// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig()
        internal
        returns (uint256, address)
    {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2_5;

        // create subscription

        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address _vrfCoordinator
    ) public returns (uint256 subId, address vrfCoordinator) {
        console2.log(
            string(
                abi.encodePacked(
                    "Creating Subscription on chainId ",
                    block.chainid,
                    " using coordinator: ",
                    _vrfCoordinator
                )
            )
        );

        vm.startBroadcast();
        subId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console2.log("Subscription created with id: ", subId);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint256 private constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinatorV2_5;
        address link = helperConfig.getConfig().link;

    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}
