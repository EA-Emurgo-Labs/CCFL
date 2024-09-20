// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IPool, DataTypes} from "@aave/core-v3/contracts/interfaces/IPool.sol";

contract MockPoolAddressesProvider is IPoolAddressesProvider {
    IPool private pool;

    constructor() payable {}

    function setPool(IPool _pool) external {
        pool = _pool;
    }

    function getMarketId() external view override returns (string memory) {
        return "";
    }

    function setMarketId(string calldata newMarketId) external override {}

    function getAddress(bytes32 id) external view override returns (address) {
        return address(this);
    }

    function setAddressAsProxy(
        bytes32 id,
        address newImplementationAddress
    ) external override {}

    function setAddress(bytes32 id, address newAddress) external override {}

    function getPool() external view override returns (address) {
        return address(pool);
    }

    function setPoolImpl(address newPoolImpl) external override {}

    function getPoolConfigurator() external view override returns (address) {
        return address(this);
    }

    function setPoolConfiguratorImpl(
        address newPoolConfiguratorImpl
    ) external override {}

    function getPriceOracle() external view override returns (address) {
        return address(this);
    }

    function setPriceOracle(address newPriceOracle) external override {}

    function getACLManager() external view override returns (address) {
        return address(this);
    }

    function setACLManager(address newAclManager) external override {}

    function getACLAdmin() external view override returns (address) {
        return address(this);
    }

    function setACLAdmin(address newAclAdmin) external override {}

    function getPriceOracleSentinel() external view override returns (address) {
        return address(this);
    }

    function setPriceOracleSentinel(
        address newPriceOracleSentinel
    ) external override {}

    function getPoolDataProvider() external view override returns (address) {
        return address(this);
    }

    function setPoolDataProvider(address newDataProvider) external override {}
}
