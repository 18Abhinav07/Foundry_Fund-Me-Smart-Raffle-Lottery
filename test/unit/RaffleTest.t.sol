// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {console2} from "forge-std/Script.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from
    "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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

    modifier raffleEntered() {
        vm.prank(PLAYER);
        /* We use
         * vm.warp() to increase the blocktime.
         * vm.roll() simulates additon of blocks.
         */
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: raffleEntranceFee}();
        _;
    }

    /*---------------- | ARRANGE --> ACT --> ASSERT |-----------------------*/

    /*//////////////////////////////////////////////////////////////
                            ENTER RAFFLE
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

    function testRaffleDoesNotAllowPlayerToEnterWhenCalculating() public raffleEntered {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                            CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseWithNoBalance() public {
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // shhould return false as contract has no balance.
        assert(!upkeepNeeded);
    }

    function testCheckupkeepReturnsFalseIfRaffleIsOpen() public raffleEntered {
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // should return false as now raffle is calculating.
        assert(!upkeepNeeded);
    }

    function testCheckupkeepReturnsFalseIfPlayersAreNone() public {
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        vm.deal(address(raffle), 1 ether); // contract is given some balance.
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // should return false as no players are there.
        assert(!upkeepNeeded);
    }

    function testCheckupkeepReturnsFalseIfTimeIntervalNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // should return false as time interval has not passed.
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepPassesWithValidParams() public raffleEntered {
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // should return true as all conditions are met.
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                            PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepRevertsIfNotUpkeepNeeded() public {
        vm.prank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                0, // Balance
                0, // Number of players
                uint256(Raffle.RaffleState.OPEN) // State of the raffle (OPEN)
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Arrange (enter raffle by the modifier)
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();

        /* the first emit will be from the chainlink VRF node and the 0 th topic is always reserved */
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    /*//////////////////////////////////////////////////////////////
                           FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /* Performing fuzzy test as we have a random argument to the test function thus foundry will test it with random values a certain amount of times (256) but can be changed in foundry.toml file. */

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(randomRequestId, address(raffle));
    }

    /* Now the local chain has a mock VRF deployed and that has very high base price and gas fees that is why with our current funds it will show insufficient funds thus we need to fund the local chain subscription more. */
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = raffleEntranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
