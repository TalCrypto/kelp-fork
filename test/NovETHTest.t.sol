// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { BaseTest } from "./BaseTest.t.sol";
import { NovETH } from "contracts/NovETH.sol";
import { LRTConfigTest, ILRTConfig, UtilLib, LRTConstants } from "./LRTConfigTest.t.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract NovETHTest is BaseTest, LRTConfigTest {
    NovETH public rseth;

    event UpdatedLRTConfig(address indexed _lrtConfig);

    function setUp() public virtual override(LRTConfigTest, BaseTest) {
        super.setUp();

        // initialize LRTConfig
        lrtConfig.initialize(admin, address(stETH), address(ethX), rsethMock);

        ProxyAdmin proxyAdmin = new ProxyAdmin();
        NovETH tokenImpl = new NovETH();
        TransparentUpgradeableProxy tokenProxy =
            new TransparentUpgradeableProxy(address(tokenImpl), address(proxyAdmin), "");

        rseth = NovETH(address(tokenProxy));
    }
}

contract NovETHInitialize is NovETHTest {
    function test_RevertWhenAdminIsZeroAddress() external {
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        rseth.initialize(address(0), address(lrtConfig));
    }

    function test_RevertWhenLRTConfigIsZeroAddress() external {
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        rseth.initialize(address(admin), address(0));
    }

    function test_InitializeContractsVariables() external {
        rseth.initialize(address(admin), address(lrtConfig));

        assertTrue(lrtConfig.hasRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin), "Admin address is not set");
        assertEq(address(lrtConfig), address(rseth.lrtConfig()), "LRT config address is not set");

        assertEq(rseth.name(), "novETH", "Name is not set");
        assertEq(rseth.symbol(), "novETH", "Symbol is not set");
    }
}

contract NovETHMint is NovETHTest {
    address public minter = makeAddr("minter");

    function setUp() public override {
        super.setUp();

        rseth.initialize(address(admin), address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, minter);
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotMinter() external {
        vm.startPrank(alice);

        string memory stringRole = string(abi.encodePacked(LRTConstants.MINTER_ROLE));
        bytes memory revertData = abi.encodeWithSelector(ILRTConfig.CallerNotLRTConfigAllowedRole.selector, stringRole);

        vm.expectRevert(revertData);

        rseth.mint(address(this), 100 ether);
        vm.stopPrank();
    }

    function test_RevertMintIsPaused() external {
        vm.startPrank(manager);
        rseth.pause();
        vm.stopPrank();

        vm.startPrank(minter);
        vm.expectRevert("Pausable: paused");
        rseth.mint(address(this), 1 ether);
        vm.stopPrank();
    }

    function test_Mint() external {
        vm.startPrank(admin);

        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, msg.sender);

        vm.stopPrank();

        vm.startPrank(minter);

        rseth.mint(address(this), 100 ether);

        assertEq(rseth.balanceOf(address(this)), 100 ether, "Balance is not correct");

        vm.stopPrank();
    }
}

contract NovETHBurnFrom is NovETHTest {
    address public burner = makeAddr("burner");

    function setUp() public override {
        super.setUp();
        rseth.initialize(address(admin), address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        lrtConfig.grantRole(LRTConstants.BURNER_ROLE, burner);

        // give minter role to admin
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, admin);
        rseth.mint(address(this), 100 ether);

        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotBurner() external {
        vm.startPrank(bob);

        string memory roleStr = string(abi.encodePacked(LRTConstants.BURNER_ROLE));
        bytes memory revertData = abi.encodeWithSelector(ILRTConfig.CallerNotLRTConfigAllowedRole.selector, roleStr);

        vm.expectRevert(revertData);

        rseth.burnFrom(address(this), 100 ether);
        vm.stopPrank();
    }

    function test_RevertBurnIsPaused() external {
        vm.prank(manager);
        rseth.pause();

        vm.prank(burner);
        vm.expectRevert("Pausable: paused");
        rseth.burnFrom(address(this), 100 ether);
    }

    function test_BurnFrom() external {
        vm.prank(burner);
        rseth.burnFrom(address(this), 100 ether);

        assertEq(rseth.balanceOf(address(this)), 0, "Balance is not correct");
    }
}

contract NovETHPause is NovETHTest {
    function setUp() public override {
        super.setUp();
        rseth.initialize(address(admin), address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);

        rseth.pause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsAlreadyPaused() external {
        vm.startPrank(manager);
        rseth.pause();

        vm.expectRevert("Pausable: paused");
        rseth.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.startPrank(manager);
        rseth.pause();

        vm.stopPrank();

        assertTrue(rseth.paused(), "Contract is not paused");
    }
}

contract NovETHUnpause is NovETHTest {
    function setUp() public override {
        super.setUp();
        rseth.initialize(address(admin), address(lrtConfig));

        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, admin);
        rseth.pause();
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);

        rseth.unpause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsNotPaused() external {
        vm.startPrank(admin);
        rseth.unpause();

        vm.expectRevert("Pausable: not paused");
        rseth.unpause();

        vm.stopPrank();
    }

    function test_Unpause() external {
        vm.startPrank(admin);
        rseth.unpause();

        vm.stopPrank();

        assertFalse(rseth.paused(), "Contract is still paused");
    }
}
