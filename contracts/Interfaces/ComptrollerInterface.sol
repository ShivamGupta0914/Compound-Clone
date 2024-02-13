//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "../CToken.sol";

interface ComptrollerInterface {

    event MarketListed(address market, uint256 collateralFactor);
    event CollateralFactorUpdated(address market, uint256 oldCollateralFactor, uint256 newCollateralFactor);
    event  MarketExited(address cToken, address account);

    struct Market {
        bool isListed;
        uint256 collateralFactor;
        mapping(address => bool) accountMembership;
    }

    struct AccountLiquidityLocalVars {
        uint256 sumCollateral;
        uint256 totalBorrows;
        uint256 cTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRate;
        uint256 collateralFactor;
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
