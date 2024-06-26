// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { Addresses, AddressesHolesky } from "../utils/Addresses.sol";

library NodeDelegatorLib {
    function deployImpl() internal returns (address implementation) {
        // Deploy the new contract
        implementation = address(new NodeDelegator());
        console.log("NodeDelegator implementation deployed at: %s", implementation);
    }

    function initialize(NodeDelegator nodeDelegator, LRTConfig config) internal {
        nodeDelegator.initialize(address(config));
    }

    // function deployInit(uint256 index) internal returns (NodeDelegator nodeDelegator) {
    //     // Deploy the new contract
    //     address nodeDelegatorImpl = address(new NodeDelegator());
    //     console.log("NodeDelegator implementation deployed at: %s", nodeDelegatorImpl);

    //     address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;
    //     bytes32 salt = keccak256(abi.encodePacked("nov-nodeDelegator", index));

    //     address proxyFactoryAddress = block.chainid == 1 ? Addresses.PROXY_FACTORY : AddressesHolesky.PROXY_FACTORY;
    //     address nodeDelegatorProxy =
    //         ProxyFactory(proxyFactoryAddress).create(nodeDelegatorImpl, proxyAdminAddress, salt);
    //     nodeDelegator = NodeDelegator(payable(nodeDelegatorProxy));

    //     // init new NodeDelegator
    //     address lrtConfigProxy = block.chainid == 1 ? Addresses.LRT_CONFIG : AddressesHolesky.LRT_CONFIG;
    //     nodeDelegator.initialize(lrtConfigProxy);

    //     console.log("Native staking node delegator (proxy) deployed at: ", nodeDelegatorProxy);
    // }

    function upgrade(address proxyAddress, address newImpl) internal returns (NodeDelegator) {
        address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;

        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
        console.log("Upgraded NodeDelegator proxy %s to new implementation %s", proxyAddress, newImpl);

        return NodeDelegator(payable(proxyAddress));
    }
}
