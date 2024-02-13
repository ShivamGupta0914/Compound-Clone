//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./Interfaces/PriceOracleInterface.sol";
import "./Interfaces/CTokenInterface.sol";

contract PriceOracle is PriceOracleInterface {

    address internal admin;
    mapping(address => uint256) internal prices;

    constructor() {
        admin = msg.sender;
    }

    function getUnderlyingPrice(address cToken) external view returns (uint256) {
        require(prices[cToken] > 0, "PRICE_NOT_SET");
        return prices[cToken];
    }

    function setUnderlyingPrice(address cToken, uint256 newPrice) external {
        require(msg.sender == admin, "NOT_AUTHORIZED");
        require(CTokenInterface(cToken).isCtoken(), "NOT_CTOKEN");

        prices[cToken] = newPrice;
        emit PriceUpdated(cToken, newPrice);
    }
}

//2608688983127312