//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface PriceOracleInterface {
    event PriceUpdated(address cToken, uint256 newPrice);

    function getUnderlyingPrice(address cToken) external view returns(uint256);
    function setUnderlyingPrice(address cToken, uint256 newPrice) external;
    
}