// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    /*------
    |EVENTS|
    --------*/

    event Raffle__Entered(address indexed player);
    event Raffle__WinnerPicked(address indexed winner);

    /*--------
    | VALUES |
    ---------*/

    Raffle public raffle;
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("player");

    // constant values.
    uint256 subscriptionId;
    bytes32 gasLane;
    uint256 automationUpdateInterval;
    uint256 raffleEntranceFee;
    uint32 callbackGasLimit;
    address vrfCoordinatorV2_5;
    address link;
    address account;

    uint256 STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        // --> use deployment script --> get the relevant raffle and helpers --> build test.
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = config.link;
        account = config.account;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                             TEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testRaffleInitializesToOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWithoutEntranceFees() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector); // use custom error for revert
        raffle.enterRaffle();
    }

    function testRaffleAddsPlayerToPlayersArray() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        assert(raffle.getPlayers()[0] == PLAYER);
    }

    function testRaffleEmitsOnEntering() public {
        vm.prank(PLAYER);
        // expect the emit and then emit the event from the test.
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle__Entered(PLAYER);

        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    function testRaffleDoesNotAllowPlayerToEnterWhenCalculating() public {
        vm.prank(PLAYER);
        /* We use
            * vm.warp() to increase the blocktime.
            * vm.roll() simulates additon of blocks.
         */
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: raffleEntranceFee}();
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }
}
