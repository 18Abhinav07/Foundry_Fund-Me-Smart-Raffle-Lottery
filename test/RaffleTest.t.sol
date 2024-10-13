// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "../src/Raffle.sol";
// import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

// contract RaffleTest is Test {
//     Raffle raffle;
//     VRFCoordinatorV2Mock vrfCoordinator;
//     address vrfCoordinatorAddress = address(0x123);
//     bytes32 keyHash = 0x0000000000000000000000000000000000000000000000000000000000000abc;
//     uint256 subscriptionId = 1;
//     uint32 callbackGasLimit = 100000;
//     uint256 entranceFee = 0.1 ether;
//     uint256 interval = 1 days;

//     function setUp() public {
//         vrfCoordinator = new VRFCoordinatorV2Mock(0, 0);
//         raffle = new Raffle(
//             entranceFee,
//             interval,
//             address(vrfCoordinator),
//             keyHash,
//             subscriptionId,
//             callbackGasLimit
//         );
//     }

//     function testEnterRaffle() public {
//         vm.deal(address(this), 1 ether);
//         raffle.enterRaffle{value: entranceFee}();
//         address payable[] memory players = raffle.getPlayers();
//         assertEq(players.length, 1);
//         assertEq(players[0], address(this));
//     }

//     function testEnterRaffleFailsWithoutEnoughEther() public {
//         vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
//         raffle.enterRaffle{value: entranceFee - 1}();
//     }

//     function testPickWinner() public {
//         vm.deal(address(this), 1 ether);
//         raffle.enterRaffle{value: entranceFee}();
//         vm.warp(block.timestamp + interval + 1);
//         raffle.perWinner();
//         // Simulate VRF callback
//         uint256[] memory randomWords = new uint256[](1);
//         randomWords[0] = 1;
//         raffle.fulfillRandomWords(0, randomWords);
//         address recentWinner = raffle.getRecentWinner();
//         assertEq(recentWinner, address(this));
//     }

//     function testPickWinnerFailsBeforeInterval() public {
//         vm.deal(address(this), 1 ether);
//         raffle.enterRaffle{value: entranceFee}();
//         vm.expectRevert();
//         raffle.pickWinner();
//     }

//     function testGetEntranceFee() public {
//         uint256 fee = raffle.getEntranceFee();
//         assertEq(fee, entranceFee);
//     }
// }