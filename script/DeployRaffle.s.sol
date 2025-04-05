//SPDX-License-Identifier:MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {createSubscriptions,FundSubscription,AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script{
    function run() public{
        DeployContract();
    }
    
    function DeployContract() public returns(Raffle,HelperConfig){
        HelperConfig helperConfig= new HelperConfig();
        HelperConfig.NetworkConfig memory config= helperConfig.getchainID();
        if (config.subscriptionid ==0){
            //create subscription
            createSubscriptions creatingSubscription = new createSubscriptions();
            (config.subscriptionid,config.vrfCoordinator)=creatingSubscription.createSubscription(config.vrfCoordinator,config.account);
        }
        //fund subscription
        FundSubscription fundsubscription= new FundSubscription();
        fundsubscription.fundSubscription(config.vrfCoordinator,config.subscriptionid,config.link,config.account);

        vm.startBroadcast(config.account);
        Raffle raffle= new Raffle(
            config.entryFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionid,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addconsumer= new AddConsumer();
        addconsumer.addConsumer(address(raffle),config.vrfCoordinator,config.subscriptionid,config.account);
        return(raffle,helperConfig);
        
    }

}