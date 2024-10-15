// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig , CodeConstants} from "./HelperConfig.s.sol";
import {CodeConstants} from "./HelperConfig.s.sol";

import {CreateSubscription} from "./Interactions.s.sol";

/**
 * @title Deploy Raffle
 * @author Abhinav Pangaria
 * @notice Deployment Script for Raffle.sol
 * @dev -
 */

contract DeployRaffle is Script, CodeConstants {
    /* RUN called 
    --> helper deployment function 
    --> Helper config object 
    --> deploy raffle with the data.*/

    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        //-> cannot use contract name to call a function
        // (Cannot call function via contract type name.solidity(3419))

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // create a subscription and a consumer if the nettworkConfig has subscriptionId is 0.
        if (config.subscriptionId == 0) {
            CreateSubscription contractSubscription = new CreateSubscription();
            (uint256 subId, address vrfCoordinatorV2_5) = contractSubscription
                .createSubscription(config.vrfCoordinatorV2_5);

            config.subscriptionId = subId;
            config.vrfCoordinatorV2_5 = vrfCoordinatorV2_5;

            // fund the subscription.
        
        }

        vm.startBroadcast();

        Raffle currentRaffle = new Raffle(
            config.raffleEntranceFee,
            config.automationUpdateInterval,
            config.vrfCoordinatorV2_5,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        vm.stopBroadcast();

        return (currentRaffle, helperConfig);
    }
}
