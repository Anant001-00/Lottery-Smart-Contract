//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/linkmock.sol";

abstract contract constants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e16;

    uint256 public constant SEPOLIA_ID = 11155111;
    uint256 public constant ANVIL_ID = 31337;
}

contract HelperConfig is Script, constants {
    error NoChainID();

    struct NetworkConfig {
        uint256 entryFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionid;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localConfig;

    constructor() {
        networkConfigs[SEPOLIA_ID] = getSepoliaconfig();
    }

    mapping(uint256 chainID => NetworkConfig) public networkConfigs;

    function getConfigByChainId(uint256 chainID) public returns (NetworkConfig memory) {
        if (networkConfigs[chainID].vrfCoordinator != address(0)) {
            return networkConfigs[chainID];
        } else if (chainID == ANVIL_ID) {
            return getorCreateLocalconfig();
        } else {
            revert NoChainID();
        }
    }

    function getchainID() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaconfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryFee: 0.01 ether,
            interval: 60,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionid: 0,
            callbackGasLimit: 50000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x6D777A1dE5B32dC4079229642482175Bb24FcC2a
        });
    }

    function getorCreateLocalconfig() public returns (NetworkConfig memory) {
        if (localConfig.vrfCoordinator != address(0)) {
            return localConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfmock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE, MOCK_WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localConfig = NetworkConfig({
            entryFee: 0.01 ether,
            interval: 60,
            vrfCoordinator: address(vrfmock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionid: 0,
            callbackGasLimit: 50000,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localConfig;
    }
}
