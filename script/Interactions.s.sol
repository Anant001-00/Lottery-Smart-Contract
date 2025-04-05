//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, constants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/linkmock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


contract createSubscriptions is Script{
    function createSubscriptionUsingConfig() public returns(uint256,address){
        HelperConfig helperConfig=new HelperConfig();
        address vrfCoordinator=helperConfig.getchainID().vrfCoordinator;
        //create subscription
        (uint256 subID, )=createSubscription(vrfCoordinator,helperConfig.getchainID().account); 
        return(subID,vrfCoordinator);

    }
    function createSubscription(address vrfCoordinator,address account) public returns(uint256,address){
        console.log("Creating a subscription on chainID: ",block.chainid);
        vm.startBroadcast(account);
        uint256 subID= VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription id is: ",subID);
        console.log("Update the subscription id in HelperConfig.s.sol");
        return(subID,vrfCoordinator);
    }

    function run() external{
        createSubscriptionUsingConfig();
    }

}
 contract FundSubscription is Script, constants{
    uint256 public constant FUND_AMOUNT=3 ether;

    function FundSubscriptionusingConfig() public{
    HelperConfig helperConfig=new HelperConfig();
    address vrfCoordinator=helperConfig.getchainID().vrfCoordinator;
    uint256 subscriptionid=helperConfig.getchainID().subscriptionid;
    address linkToken=helperConfig.getchainID().link;
    address account=helperConfig.getchainID().account;
    fundSubscription(vrfCoordinator,subscriptionid,linkToken,account);
}
    function fundSubscription(address vrfCoordinator, uint256 subscriptionid, address linkToken,address account) public{
        console.log("Funding subscription with id: ",subscriptionid);
        console.log("Using VrfCoordinator : ",vrfCoordinator);
        console.log("On chainid: ",block.chainid);

        if (block.chainid==ANVIL_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionid,FUND_AMOUNT*300);
            vm.stopBroadcast();
        }
        else{
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subscriptionid));
            vm.stopBroadcast();

        }
    }
   function run() external{
        FundSubscriptionusingConfig();

   } 
 }
 contract AddConsumer is Script{
    function addConsumerUsingConfig(address mostRecentlyDeployed) public{
        HelperConfig helperConfig=new HelperConfig();
        address vrfCoordinator=helperConfig.getchainID().vrfCoordinator;
        uint256 subscriptionid=helperConfig.getchainID().subscriptionid;
        address account=helperConfig.getchainID().account;
        addConsumer(mostRecentlyDeployed,vrfCoordinator,subscriptionid,account);

    }
    function addConsumer(address mostRecent,address vrfCoordinator , uint256 subscriptionid,address account) public{
        console.log("This address is added as the new consumer: ",mostRecent);
        console.log("Using vrf coordinator: ",vrfCoordinator);
        console.log("On chain id: ",block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionid,mostRecent);
        vm.stopBroadcast();
    }
    function run() external{
        address mostRecentlyDeployed= DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
 }