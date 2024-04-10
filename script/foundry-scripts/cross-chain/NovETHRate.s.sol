// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { NovETHRateProvider } from "contracts/cross-chain/NovETHRateProvider.sol";
import { NovETHRateReceiver } from "contracts/cross-chain/NovETHRateReceiver.sol";

contract DeployNovETHRateProvider is Script {
    function run() external {
        vm.startBroadcast();

        if (block.chainid != 1) {
            revert("Must be deployed on mainnet");
        }

        address novETHOracle = 0x349A73444b1a310BAe67ef67973022020d70020d;
        uint16 layerZeroDstChainId = 158; // Layer Zero id for Polygon ZKEVM
        address layerZeroEndpoint = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;

        address novETHRateProviderContractAddress =
            address(new NovETHRateProvider(novETHOracle, layerZeroDstChainId, layerZeroEndpoint));

        console.log("NovETHRateProvider deployed at: %s", address(novETHRateProviderContractAddress));

        vm.stopBroadcast();
    }
}

contract DeployNovETHRateReceiver is Script {
    function run() external {
        vm.startBroadcast();

        if (block.chainid != 1101) {
            revert("Must be deployed on polygon ZKEVM");
        }

        address rateProviderOnEthMainnet = 0xF1cccBa5558D31628216489A1435e068b1fd2C8A;
        uint16 layerZeroSrcChainId = 101; // Layer Zero id for Ethereum mainnet
        address layerZeroEndpoint = 0x9740FF91F1985D8d2B71494aE1A2f723bb3Ed9E4; // LZ endpoint for polygon ZKEVM

        address novETHRateReceiverContractAddress =
            address(new NovETHRateReceiver(layerZeroSrcChainId, rateProviderOnEthMainnet, layerZeroEndpoint));

        console.log("NovETHRateReceiver deployed at: %s", address(novETHRateReceiverContractAddress));

        vm.stopBroadcast();
    }
}
