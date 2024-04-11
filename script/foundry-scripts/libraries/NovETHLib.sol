// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { LRTConfig } from "contracts/LRTConfig.sol";
import { NovETH } from "contracts/NovETH.sol";
import { LRTConstants } from "contracts/utils/LRTConstants.sol";
import { Addresses, AddressesHolesky } from "../utils/Addresses.sol";
import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";

library NovETHLib {
    function deployImpl() internal returns (address implementation) {
        // Deploy the new contract
        implementation = address(new NovETH());
        console.log("NovETH implementation deployed at: %s", implementation);
    }

    function deployProxy(
        address implementation,
        ProxyAdmin proxyAdmin,
        ProxyFactory proxyFactory
    )
        internal
        returns (NovETH novETH)
    {
        address proxy = proxyFactory.create(implementation, address(proxyAdmin), LRTConstants.SALT);
        console.log("NovETH proxy deployed at: ", proxy);

        novETH = NovETH(proxy);
    }

    function initialize(NovETH novETH, LRTConfig config) internal {
        novETH.initialize(address(config));
    }

    // function upgrade(address newImpl) internal returns (NovETH) {
    //     address proxyAdminAddress = block.chainid == 1 ? Addresses.PROXY_ADMIN : AddressesHolesky.PROXY_ADMIN;
    //     address proxyAddress = block.chainid == 1 ? Addresses.NOV_ETH : AddressesHolesky.NOV_ETH;

    //     ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);

    //     proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImpl);
    //     console.log("Upgraded NovETH proxy %s to new implementation %s", proxyAddress, newImpl);

    //     return NovETH(proxyAddress);
    // }
}
