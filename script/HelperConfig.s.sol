// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {Raffle} from "src/Raffle.sol";

import {VRFCoordinatorV2_5Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @title Helper Config
 * @author Abhinav Pangaria
 * @notice A configuration file that will provide the essential network related data that will be
 * used to put the contract on testing and further deployment.
 * @dev -
 */

abstract contract CodeConstants {
    /* MOCK VRF CONSTANTS */
    uint96 public constant baseFee = 0.25 ether;
    uint96 public constant gasPrice = 1e9;
    // LINK to ETH price.
    int256 public constant weiPerUnitLink = 4e15;

    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    /*------
    |ERRORS|
    --------*/

    error HelperConfig__InvalidChainId();

    /*---------------------------------------------------------------------------------------------------------------
    A network configuration struct that will provide the essential configs to the constructor of the Raffle__contract.
    -----------------------------------------------------------------------------------------------------------------*/

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 gasLane;
        uint256 automationUpdateInterval;
        uint256 raffleEntranceFee;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2_5;
        address link;
        address account;
    }

    NetworkConfig private currentNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getETHMainnetConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getETHSepoliaConfig();
        networkConfigs[ETH_LOCAL_CHAIN_ID] = getOrCreateETHLocalConfig();
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainId
    ) public view returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == ETH_LOCAL_CHAIN_ID) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    // NETWORK FUNCTIONS-->

    function getETHMainnetConfig()
        public
        pure
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        mainnetNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            automationUpdateInterval: 30, // 30 seconds
            raffleEntranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            link: address(0),
            account: address(0)
        });
    }

    function getETHSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            subscriptionId: 0, // If left as 0, our scripts will create one!
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            automationUpdateInterval: 30, // 30 seconds
            raffleEntranceFee: 0.01 ether, // 1e16
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: address(0), // You can update the LINK token address as needed
            account: address(0) // Owner account
        });
    }

    function getOrCreateETHLocalConfig()
        public
        returns (NetworkConfig memory localNetworkConfig)
    {
        if (currentNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[ETH_LOCAL_CHAIN_ID];
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock mockVRFcoordinator = new VRFCoordinatorV2_5Mock(
            baseFee,
            gasPrice,
            weiPerUnitLink
        );
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: 0, // For local testing, this can be 0
            gasLane: 0x0000000000000000000000000000000000000000000000000000000000000000, // Placeholder gas lane
            automationUpdateInterval: 30, // 30 seconds
            raffleEntranceFee: 0.01 ether,
            callbackGasLimit: 500000, // 500,000 gas
            vrfCoordinatorV2_5: address(mockVRFcoordinator), // Mock VRF coordinator for local testing
            link: address(0), // You can update with the local LINK token mock
            account: address(0) // You can update with a test account if needed
        });
    }
}
