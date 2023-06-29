//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ComptrollerInterface {

    struct Market {
        bool isListed;
        uint collateralFactorMantissa;
        mapping(address => bool) accountMembership;
    }

    struct AccountLiquidityLocalVars {
        uint totalCollateral;
        uint totalBorrows;
        uint cTokenBalance;
        uint borrowBalance;
        uint exchangeRate;
    
    }
    function redeemAllowed() external returns(bool);
    function borrowAllowed() external returns(bool);
    function mintAllowed() external returns(bool);
    function repayAllowed() external returns(bool);
}