// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { NovETH } from "contracts/NovETH.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { ChainlinkPriceOracle } from "contracts/oracles/ChainlinkPriceOracle.sol";
import { EthXPriceOracle } from "contracts/oracles/EthXPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { ConfigLib } from "../libraries/ConfigLib.sol";
import { NovETHLib } from "../libraries/NovETHLib.sol";
import { DepositPoolLib } from "../libraries/DepositPoolLib.sol";
import { OraclesLib } from "../libraries/OraclesLib.sol";
import { NodeDelegatorLib } from "../libraries/NodeDelegatorLib.sol";
import { Addresses, AddressesHolesky } from "../utils/Addresses.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { MockPriceAggregator } from "script/foundry-scripts/utils/MockPriceAggregator.sol";

contract DeployAll is Script {
    uint256 public constant MAX_DEPOSITS = 1000 ether;

    bool public isForked;

    address public deployerAddress;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfig;
    NovETH public novETH;
    LRTDepositPool public depositPool;
    LRTOracle public lrtOracle;
    address public chainlinkPriceOracleAddress;
    address public ethXPriceOracleAddress;
    NodeDelegator public node1;
    NodeDelegator public node2;
    address[] public nodeDelegatorContracts;

    address public stETHPriceFeed;
    address public ethxPriceFeed;

    uint256 public minAmountToDeposit;

    function _maxApproveToEigenStrategyManager(address nodeDel) internal {
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(AddressesHolesky.STETH_TOKEN);
        NodeDelegator(payable(nodeDel)).maxApproveToEigenStrategyManager(AddressesHolesky.ETHX_TOKEN);
    }

    function _setUpByAdmin() internal {
        // add novETH to LRT config
        lrtConfig.setNovETH(address(novETH));

        // add oracle to LRT config
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(lrtOracle));

        // add contracts to LRT config
        lrtConfig.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(depositPool));
        lrtConfig.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, AddressesHolesky.EIGEN_STRATEGY_MANAGER);
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, AddressesHolesky.EIGEN_POD_MANAGER);

        // call updateAssetStrategy for each asset in LRTConfig
        lrtConfig.updateAssetStrategy(AddressesHolesky.STETH_TOKEN, AddressesHolesky.STETH_EIGEN_STRATEGY);
        lrtConfig.updateAssetStrategy(AddressesHolesky.ETHX_TOKEN, AddressesHolesky.ETHX_EIGEN_STRATEGY);

        // Set SSV contract addresses in LRTConfig
        lrtConfig.setContract(LRTConstants.SSV_TOKEN, AddressesHolesky.SSV_TOKEN);
        lrtConfig.setContract(LRTConstants.SSV_NETWORK, AddressesHolesky.SSV_NETWORK);

        // grant MANAGER_ROLE to deployer and Holesky Defender Relayer
        lrtConfig.grantRole(LRTConstants.MANAGER, deployerAddress);
        lrtConfig.grantRole(LRTConstants.MANAGER, AddressesHolesky.RELAYER);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, deployerAddress);
        lrtConfig.grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, AddressesHolesky.RELAYER);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, deployerAddress);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, AddressesHolesky.RELAYER);

        // add minter role to lrtDepositPool so it mints novETH
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, address(depositPool));

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(node1));

        depositPool.addNodeDelegatorContractToQueue(nodeDelegatorContracts);

        // add min amount to deposit in LRTDepositPool
        depositPool.setMinAmountToDeposit(minAmountToDeposit);

        // Approve 1nd NodeDelegator to transfer SSV tokens
        node1.approveSSV();
    }

    function _setUpByManager() internal {
        // Add chainlink oracles for supported assets in ChainlinkPriceOracle
        ChainlinkPriceOracle(chainlinkPriceOracleAddress).updatePriceFeedFor(
            AddressesHolesky.STETH_TOKEN, stETHPriceFeed
        );

        // call updatePriceOracleFor for each asset in LRTOracle
        lrtOracle.updatePriceOracleFor(AddressesHolesky.STETH_TOKEN, chainlinkPriceOracleAddress);
        lrtOracle.updatePriceOracleFor(AddressesHolesky.ETHX_TOKEN, ethXPriceOracleAddress);

        // _maxApproveToEigenStrategyManager in each NodeDelegator to transfer to strategy
        _maxApproveToEigenStrategyManager(address(node1));

        // Create and EigenPod for the 2nd NodeDelegator
        node1.createEigenPod();
    }

    function run() external {
        if (block.chainid != 17_000) {
            revert("Not holesky");
        }

        isForked = vm.envOr("IS_FORK", false);
        if (isForked) {
            address mainnetProxyOwner = AddressesHolesky.PROXY_OWNER;
            console.log("Running script on Holesky fork impersonating: %s", mainnetProxyOwner);
            vm.startPrank(mainnetProxyOwner);
        } else {
            uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            address deployer = vm.rememberKey(deployerPrivateKey);
            vm.startBroadcast(deployer);
            console.log("Deploying on Holesky with deployer: %s", deployer);
        }

        proxyFactory = new ProxyFactory();
        proxyAdmin = new ProxyAdmin(); // msg.sender becomes the owner of ProxyAdmin

        deployerAddress = proxyAdmin.owner();
        minAmountToDeposit = 0.0001 ether;

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Proxy factory deployed at: ", address(proxyFactory));
        console.log("Tentative owner of ProxyAdmin: ", deployerAddress);

        // LRTConfig
        address lrtConfigImplementation = ConfigLib.deployImpl();
        lrtConfig = ConfigLib.deployProxy(lrtConfigImplementation, proxyAdmin, proxyFactory);

        // NovETH
        address novETHImplementation = NovETHLib.deployImpl();
        novETH = NovETHLib.deployProxy(novETHImplementation, proxyAdmin, proxyFactory);

        // Initialize LRTConfig
        address novETHProxyAddress =
            proxyFactory.computeAddress(novETHImplementation, address(proxyAdmin), LRTConstants.SALT);
        assert(address(novETH) == novETHProxyAddress);
        console.log("predicted novETH proxy address: ", novETHProxyAddress);
        ConfigLib.initialize(lrtConfig, deployerAddress, novETHProxyAddress);

        // Initialize NovETH
        NovETHLib.initialize(novETH, lrtConfig);

        // LRTDepositPool
        address lrtDepositPoolImplementation = DepositPoolLib.deployImpl();
        depositPool = DepositPoolLib.deployProxy(lrtDepositPoolImplementation, proxyAdmin, proxyFactory);
        DepositPoolLib.initialize(depositPool, lrtConfig);

        // LRTOracle
        address lrtOracleImplementation = OraclesLib.deployLRTOracleImpl();
        lrtOracle = OraclesLib.deployLRTOracleProxy(lrtOracleImplementation, proxyAdmin, proxyFactory);
        OraclesLib.initializeLRTOracle(lrtOracle, lrtConfig);

        // ChainlinkPriceOracle
        chainlinkPriceOracleAddress = OraclesLib.deployInitChainlinkOracle(proxyAdmin, proxyFactory, lrtConfig);
        ethXPriceOracleAddress = OraclesLib.deployInitEthXPriceOracle(proxyAdmin, proxyFactory);
        address ethOracleProxy = OraclesLib.deployInitETHOracle(proxyAdmin, proxyFactory);

        // DelegatorNode
        address nodeImpl = NodeDelegatorLib.deployImpl();
        node1 = NodeDelegatorLib.deployProxy(nodeImpl, proxyAdmin, proxyFactory, 1);
        NodeDelegatorLib.initialize(node1, lrtConfig);

        // Transfer SSV tokens to the native staking NodeDelegator
        // SSV Faucet https://faucet.ssv.network/
        IERC20(AddressesHolesky.SSV_TOKEN).transfer(address(node1), 30 ether);

        // Mock aggregators
        stETHPriceFeed = address(new MockPriceAggregator());

        // setup
        _setUpByAdmin();
        _setUpByManager();

        // ETH asset setup
        lrtConfig.addNewSupportedAsset(LRTConstants.ETH_TOKEN_ADDRESS, MAX_DEPOSITS);
        lrtOracle.updatePriceOracleFor(LRTConstants.ETH_TOKEN_ADDRESS, ethOracleProxy);

        // update prETHPrice
        lrtOracle.updateNovETHPrice();

        proxyAdmin.transferOwnership(AddressesHolesky.PROXY_OWNER);
        console.log("ProxyAdmin ownership transferred to: ", AddressesHolesky.PROXY_OWNER);

        if (isForked) {
            vm.stopPrank();
        } else {
            vm.stopBroadcast();
        }
    }
}
