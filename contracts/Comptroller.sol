//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./ComptrollerInterface.sol";
import "./CToken.sol";

contract Comptroller is ComptrollerInterface {
    mapping(address => Market) markets;
    mapping(address => CToken[]) accountAssets;

    function joinMarket(CToken cToken, address account) public {
        require(markets[address(cToken)].isListed, "market is not listed");

        if (markets[address(cToken)].accountMembership[account]) return;

        markets[address(cToken)].accountMembership[account] = true;
        accountAssets[account].push(cToken);
    }

    function checkMembership(
        address account,
        address cToken
    ) external view returns (bool) {
        return markets[cToken].accountMembership[account];
    }

    //////////////////////////////////
    function exitMarket(address cToken) external {}

    /////////////////////

    function mintAllowed(address cToken) external view returns (bool) {
        if (!markets[cToken].isListed) {
            return false;
        }

        return true;
    }

    function redeemAllowed(
        address cToken,
        address redeemer,
        uint256 redeemTokens
    ) external view returns (bool) {
        if (!markets[cToken].isListed) {
            return false;
        }

        if (!markets[cToken].accountMembership[redeemer]) {
            return true;
        }

        (, uint shortfall) = getLiquidityInformation(
            redeemer,
            CToken(cToken),
            redeemTokens,
            0
        );

        if (shortfall > 0) {
            return false;
        }

        return true;
    }

    function borrowAllowed(
        address cToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (bool) {
        require(markets[cToken].isListed, "market not listed");

        if (!markets[cToken].accountMembership[borrower]) {
            joinMarket(CToken(cToken), borrower);
        }

        (, uint256 shortfall) = getLiquidityInformation(
            borrower,
            CToken(cToken),
            0,
            borrowAmount
        );
        if (shortfall > 0) {
            return false;
        }

        return true;
    }

    function repayAllowed(address cToken) external view returns (bool) {
        if (markets[cToken].isListed) return true;
        return false;
    }

    function getLiquidityInformation(
        address account,
        CToken cToken,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) internal view returns (uint256, uint256) {
        AccountLiquidityLocalVars memory vars;

        CToken[] memory assets = accountAssets[account];
        for (uint i = 0; i < assets.length; i++) {
            CToken asset = assets[i];

            (
                vars.cTokenBalance,
                vars.borrowBalance,
                vars.exchangeRateMantissa 
            ) = asset.getAccountSnapshot(account);

            uint256 collateralFactor = markets[address(asset)]
                .collateralFactorMantissa;
            uint256 exchangeRate = vars.exchangeRateMantissa;

            uint256 tokensToDenom = collateralFactor *
                exchangeRate *
                1;
            vars.sumCollateral += tokensToDenom * vars.cTokenBalance;
            vars.totalBorrows += 1 * vars.borrowBalance;

            if (asset == cToken) {
                vars.totalBorrows += tokensToDenom * redeemTokens;
                vars.totalBorrows += 1 * borrowAmount;
            }
        }

        if (vars.sumCollateral > vars.totalBorrows) {
            return (vars.sumCollateral - vars.totalBorrows, 0);
        } else {
            return (0, vars.totalBorrows - vars.sumCollateral);
        }
    }
}
