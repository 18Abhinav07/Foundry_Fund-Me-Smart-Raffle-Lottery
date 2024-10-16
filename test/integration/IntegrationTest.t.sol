// SPDX-License-Identtifier: MIT

pragma solidity ^0.8.0;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract IntegrationTest is Test {
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig config;
    CreateSubscription contractSubscription;
    Raffle currentRaffle;

    function setUp() external {
        helperConfig = new HelperConfig();
        config = helperConfig.getConfig();
        contractSubscription = new CreateSubscription();
        uint256 subId = contractSubscription.createSubscription(
            config.vrfCoordinatorV2_5,
            config.account
        );
        config.subscriptionId = subId;

        vm.startBroadcast(config.account);
        currentRaffle = new Raffle(
            config.raffleEntranceFee,
            config.automationUpdateInterval,
            config.vrfCoordinatorV2_5,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
    }

    function testCreateSubscriptionGeneratesAValidSubId() public view {
        assertTrue(
            config.subscriptionId > 0,
            "Subscription ID should be greater than 0"
        );
    }

    function testFundSubscriptionFundsWithValidFunds() public {
        FundSubscription contractFundSubscription = new FundSubscription();
        contractFundSubscription.fundSubscription(
            config.subscriptionId,
            config.vrfCoordinatorV2_5,
            config.link,
            config.account
        );
        (uint96 balance, , , , ) = VRFCoordinatorV2_5Mock(
            helperConfig.getConfig().vrfCoordinatorV2_5
        ).getSubscription(config.subscriptionId);

        assertTrue(balance > 0, "Link balance should be greater than 0");
    }

    function testAddConsumerAddsConsumerToSubscription() public {
        FundSubscription contractFundSubscription = new FundSubscription();
        contractFundSubscription.fundSubscription(
            config.subscriptionId,
            config.vrfCoordinatorV2_5,
            config.link,
            config.account
        );

        AddConsumer contractAddConsumer = new AddConsumer();
        contractAddConsumer.addConsumer(
            address(currentRaffle),
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            config.account
        );

        (
            uint96 balance,
            uint96 nativeBalance,
            uint64 reqCount,
            address subOwner,
            address[] memory consumers
        ) = VRFCoordinatorV2_5Mock(helperConfig.getConfig().vrfCoordinatorV2_5)
                .getSubscription(config.subscriptionId);

        console.log("Balance:", balance);
        console.log("Native Balance:", nativeBalance);
        console.log("Req Count:", reqCount);
        console.log("Sub Owner:", subOwner);

        assert(consumers[0] == address(currentRaffle));
    }

    function testCreateSubFundSubAddConsumerWorksByConfig() public {
        /*
         * 1. Create a subscription
         * 2. Fund the subscription
         * 3. Add consumer
         *
         * @dev the internal tests of the createByConfig fucntions we need to pass a coherent subId, vrfCoordinator and raffle account as when the fucnctions being tested take the subId from here but the vrf annd raffle from their internal calls the subscription does not match and comes out invalid.
         */
        CreateSubscription t_createSub = new CreateSubscription();
        FundSubscription t_fundSub = new FundSubscription();
        AddConsumer t_addConsumer = new AddConsumer();

        uint256 subId = t_createSub.run();
        t_fundSub.run(config.subscriptionId, config.vrfCoordinatorV2_5);

        t_addConsumer.run(
            address(currentRaffle),
            config.subscriptionId,
            config.vrfCoordinatorV2_5
        );
        (
            uint96 balance,
            ,
            ,
            ,
            address[] memory consumers
        ) = VRFCoordinatorV2_5Mock(config.vrfCoordinatorV2_5).getSubscription(
                config.subscriptionId
            );

        assert(subId > 0);
        assert(balance > 0);
        assert(consumers.length > 0);
    }
}
