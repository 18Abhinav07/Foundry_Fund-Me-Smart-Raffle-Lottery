// SPDX-License-Identifier: MIT

/**
 * @title Raffle
 * @author Abhinav Pangaria
 * @notice A sample raffle lottery contract
 * @dev Implementing ChainlinkVRF2.5
 */

pragma solidity ^0.8.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /*------
    |ERRORS|
    --------*/

    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();

    /*------
    |EVENTS|
    --------*/

    event Raffle__Entered(address indexed player);
    event Raffle__WinnerPicked(address indexed winner);

    /*----------------
    |TYPE DECLARATION|
    ------------------*/

    // states are numbered order wise in enums 0-> OPEN and so on.
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /*---------------
    |STATE VARIABLES|
    -----------------*/

    uint256 private immutable i_entranceFees;

    //@dev the time interval after which winner is to be picked.
    uint256 private immutable i_interval;

    // as one of the player will win thus the address needs to be paybale to send eth.
    address payable[] s_players;

    uint256 private s_lastTimeStamp;

    address payable private s_recentWinner;

    RaffleState private s_raffleState;

    // these are the needed struct values for the requestRandomWords.

    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    uint32 private constant NUM_WORDS = 1;

    bytes32 private immutable i_keyHash;

    uint256 private immutable i_subscriptionId;

    uint32 private immutable i_callbackGasLimit;

    // bool private enableNativePayment;

    /*-----------
    |CONSTRUCTOR|
    -------------*/

    /*
    We need to pass the inherited contracts constructor here.
    */

    constructor(
        uint256 entranceFees,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFees = entranceFees;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // s_raffleState = RaffleState(0);
    }

    /*------------------
    |CONTRACT FUNCTIONS|
    --------------------*/
    // external -> public -> internal -> private

    function enterRaffle() external payable {
        // user needs to send an entrance fees.
        if (msg.value < i_entranceFees) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        // raffle needs to be open to enter.
        if (s_raffleState != RaffleState(0)) {
            revert Raffle__NotOpen();
        }

        s_players.push(payable(msg.sender));

        emit Raffle__Entered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */

    // when the return values are initiated in the returns statement we don't need a
    // return statement.

    function checkUpkeep(
        bytes memory /* checkData */
        // Due to a function argument in a contract called inside a contract cannot be calldata
        // thus we need to use memory so that we can pass a empty string otherwise implicit
        //conversion not possible.
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "");
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */

    function performUpkeep(bytes calldata /*performData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep('');

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        // check to see if enough time has passed
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // we can pay the subscription using native eth to apart from link
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        //s_vrfCoordinator inherited from the BaseV2Plus
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        // log that a winner has been picked.
        emit Raffle__WinnerPicked(s_recentWinner);

        //reset the states to a new raffle.
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        // transfer the balance to the winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /*----------------
    |GETTER FUNCTIONS|
    -----------------*/

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFees;
    }

    function getPlayers() public view returns (address payable[] memory) {
        return s_players;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
