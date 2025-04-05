//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/Script.sol";
/**
 * @title Raffle
 * @author Anant Ojha
 * @notice Raffle contract using Chainlink VRF
 * @dev It implements Chainlink VRFv2.5 and Chainlink Automation
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__NotEnoughEth();
    error Raffle__TransactionFailed();
    error Raffle__RaffleUnavailable();
    error Raffle_upkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    /* Enum */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval;

    //Vrf state variables
    //VRFCoordinatorV2Interface immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address payable[] private s_Participants;
    uint256 private s_lastTimeStamp;
    address private s_Winner;
    RaffleState private s_raffleState;

    constructor(
        uint256 entryFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint256 subscriptionid,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = entryFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        //i_vrfCoordinator = vrfCoordinator;

        i_keyHash = gaslane;
        i_subscriptionId = subscriptionid;
        //REQUEST_CONFIRMATIONS = 3;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }
    /* Event */

    event EnteredRaffle(address indexed participant);
    event WinnerPicked(address indexed winner);
    event GetRequestId(uint256 indexed requestId);

    function enterraffle() external payable {
        //require(msg.value>i_entryFee,"Not enough ETH"); costs more gas
        //require(msg.value>i_entryFee, NotEnoughEth());  works for version 8.4 and above
        if (msg.value < i_entryFee) {
            revert Raffle__NotEnoughEth();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleUnavailable();
        }
        s_Participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /*check data*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_Participants.length > 0;
        upkeepNeeded = isOpen && timePassed && hasBalance && hasPlayers;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_upkeepNotNeeded(address(this).balance, s_Participants.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        uint256 s_requestId = s_vrfCoordinator.requestRandomWords(request);
        emit GetRequestId(s_requestId); //Basically Redundant
    }

    function fulfillRandomWords(uint256 s_requestId, uint256[] calldata randomWords) internal override {
        uint256 WinnerIndex = randomWords[0] % s_Participants.length;
        address payable Winner = s_Participants[WinnerIndex];
        s_Winner = Winner;
        s_raffleState = RaffleState.OPEN;
        s_Participants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = Winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransactionFailed();
        }
        emit WinnerPicked(Winner);
        console.log(s_requestId);
    }
    /**
     * Getter Function
     */

    function getEntryFee() external view returns (uint256) {
        return i_entryFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_Participants[indexOfPlayer];
    }

    function getWinner() external view returns (address) {
        return s_Winner;
    }

    function getlastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getplayerlength() external view returns (uint256) {
        return s_Participants.length;
    }
}
