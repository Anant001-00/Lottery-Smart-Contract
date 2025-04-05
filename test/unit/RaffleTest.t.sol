//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, constants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test, constants {
    Raffle public raffle;
    HelperConfig public helperconfig;
    address public Player = makeAddr("Player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 entryFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionid;
    uint256 callbackGasLimit;

    event EnteredRaffle(address indexed participant);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperconfig) = deployer.DeployContract();
        HelperConfig.NetworkConfig memory config = helperconfig.getchainID();
        entryFee = config.entryFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionid = config.subscriptionid;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(Player, STARTING_BALANCE);
    }

    function testInitialRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testCannotEnterRaffleWithoutEnough() public {
        vm.prank(Player);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterraffle();
    }

    function testPlayerListGetsUpdated() public {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        address FirstPlayer = raffle.getPlayer(0);
        assert(FirstPlayer == Player);
    }

    function testEmitPlayerEntered() public {
        vm.prank(Player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(Player);
        raffle.enterraffle{value: entryFee}();
    }

    function testNoEntryWhenCalculating() public {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleUnavailable.selector);
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
    }

    function testCheckUpKeepreturnsfalsefornobalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testcheckUpKeepreturnsFalsewehnraffleisntOpen() public {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepreturnsfalseifenoughtimehasnotpassed() public {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepreturnstruewhenParametersaregood() public {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testperformUpkeepcanonlyrunwhenCheckUpKeepistrue() public {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    function testperformupKeeprevertsifCheckupKeepisfalse() public {
        uint256 curBalance = 0;
        uint256 noofPlayers = 0;
        Raffle.RaffleState curState = raffle.getRaffleState();

        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        curBalance += entryFee;
        noofPlayers += 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_upkeepNotNeeded.selector, curBalance, noofPlayers, curState)
        );
        raffle.performUpkeep("");
    }

    modifier RaffleEntered() {
        vm.prank(Player);
        raffle.enterraffle{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid == SEPOLIA_ID) {
            return;
        } else {
            _;
        }
    }

    function testPerformUpKeepupdatesRaffleStateandEmitsRequestId() public RaffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //console.log(entries);  Needs to be checked
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState curState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(curState == Raffle.RaffleState.CALCULATING);
    }

    function testfulfillrandomwordsonlyCalledafterperformupkeep(uint256 reqid) public skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(reqid, address(raffle));
    }

    function testfulfillrandomwordspickswinnerresetsandgivesmoney() public RaffleEntered skipFork {
        uint256 extraPlayers = 4;
        uint256 startIndex = 1;

        uint256 startingtimeStamp = raffle.getlastTimeStamp();
        for (uint256 i = startIndex; i < startIndex + extraPlayers; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterraffle{value: entryFee}();
        }

        address expectedwinner = address(1);
        uint256 winnerStartBalance = expectedwinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getWinner();
        Raffle.RaffleState curState = raffle.getRaffleState();
        uint256 recentTimeStamp = raffle.getlastTimeStamp();
        uint256 winnerBalance = recentWinner.balance;
        uint256 prize = entryFee * (extraPlayers + 1);

        assert(recentWinner == expectedwinner);
        assert(curState == Raffle.RaffleState.OPEN);
        assert(recentTimeStamp > startingtimeStamp);
        assert(winnerBalance == winnerStartBalance + prize);
    }
}
