// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConfigRoleChecker, ILRTConfig, LRTConstants } from "./utils/LRTConfigRoleChecker.sol";

import { ERC20Upgradeable, Initializable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title novETH token Contract
/// @author Stader Labs
/// @notice The ERC20 contract for the novETH token
contract NovETH is Initializable, LRTConfigRoleChecker, ERC20Upgradeable, PausableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);

        __ERC20_init("novETH", "novETH");
        __Pausable_init();
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /// @notice Mints novETH when called by an authorized caller
    /// @param to the account to mint to
    /// @param amount the amount of novETH to mint
    function mint(address to, uint256 amount) external onlyRole(LRTConstants.MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }

    /// @notice Burns novETH when called by an authorized caller
    /// @param account the account to burn from
    /// @param amount the amount of novETH to burn
    function burnFrom(address account, uint256 amount) external onlyRole(LRTConstants.BURNER_ROLE) whenNotPaused {
        _burn(account, amount);
    }

    /// @dev Triggers stopped state.
    /// @dev Only callable by LRT config manager. Contract must NOT be paused.
    function pause() external onlyLRTManager {
        _pause();
    }

    /// @notice Returns to normal state.
    /// @dev Only callable by the novETH admin. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
    }
}
