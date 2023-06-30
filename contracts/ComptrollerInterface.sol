//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./CToken.sol";

interface ComptrollerInterface {
    struct Market {
        bool isListed;
        uint256 collateralFactorMantissa;
        mapping(address => bool) accountMembership;
    }

    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint totalBorrows;
        uint cTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
    }

    function mintAllowed(address cToken) external returns (bool);

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint256 redeemTokens
    ) external returns (bool);

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (bool);

    function repayAllowed(address cToken) external returns (bool);
}
