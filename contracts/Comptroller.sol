//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./CToken.sol";
import "./Interfaces/ComptrollerInterface.sol";
import "./Interfaces/PriceOracleInterface.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";


contract Comptroller is ComptrollerInterface, Initializable {
    address admin;
    PriceOracleInterface oracle;
    bool private locked;
    mapping(address => Market) markets;
    mapping(address => CToken[]) accountAssets;

    function initialize(address _admin, PriceOracleInterface _oracle) external initializer {
        admin = _admin;
        oracle = _oracle;
    }

    function listMarket(address cToken, uint256 collateralFactor) external {
        require(msg.sender == admin, "NOT_AUTHORIZED");
        require(CToken(cToken).isCtoken(), "NOT_CTOKEN");

        if(markets[cToken].isListed) return;

        markets[cToken].isListed = true;
        setCollateralFactor(cToken, collateralFactor);

        emit MarketListed(cToken, collateralFactor);
    }

    function joinMarket(CToken cToken, address account) public {
        require(markets[address(cToken)].isListed, "MARKET_NOT_LISTED");

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

    function exitMarket(address cTokenAddress) external {
        CToken cToken = CToken(cTokenAddress);
        ( uint256 cTokenBalance, uint256 borrowBalance, ) = cToken.getAccountSnapshot(msg.sender);

        require(borrowBalance == 0, "PENDING_REPAY");
    
        bool status = redeemAllowed(cTokenAddress, msg.sender, cTokenBalance);
        require(status, "CANNOT_EXIT_MARKET");

        Market storage marketToExit = markets[cTokenAddress];

        if (!marketToExit.accountMembership[msg.sender]) {
            return;
        }

        delete marketToExit.accountMembership[msg.sender];

        CToken[] memory userAssetList = accountAssets[msg.sender];
        uint len = userAssetList.length;
        uint assetIndex = len;
        for (uint i = 0; i < len; i++) {
            if (userAssetList[i] == cToken) {
                assetIndex = i;
                break;
            }
        }

        CToken[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();

        emit MarketExited(cTokenAddress, msg.sender);
    }

    function setCollateralFactor(address cToken, uint256 newCollateralFactor) public {
        require(msg.sender  == admin, "NOT_AUTHORIZED");
        require(newCollateralFactor <= 0.85e18, "VERY_HIGH_COLLATERAL_FACTOR");
        require(markets[cToken].isListed, "MARKET_NOT_LISTED");

        uint256 oldCollateralFactor = markets[cToken].collateralFactor;
        markets[cToken].collateralFactor = newCollateralFactor;

        emit CollateralFactorUpdated(cToken, oldCollateralFactor, newCollateralFactor);
    }

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
    ) public view returns (bool) {
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
        require(markets[cToken].isListed, "MARKET_NOT_LISTED");

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

            ( vars.cTokenBalance, vars.borrowBalance, vars.exchangeRate ) = asset.getAccountSnapshot(account);

            vars.collateralFactor = markets[address(asset)].collateralFactor;

            uint256 tokensToDenom = (vars.collateralFactor * vars.exchangeRate * oracle.getUnderlyingPrice(address(cToken))) / 1e36;
            vars.sumCollateral += (tokensToDenom * vars.cTokenBalance) / 1e18;
            vars.totalBorrows += (oracle.getUnderlyingPrice(address(cToken)) * vars.borrowBalance) / 1e18;

            if (asset == cToken) {
                vars.totalBorrows += (tokensToDenom * redeemTokens) / 1e18;

                vars.totalBorrows += (oracle.getUnderlyingPrice(address(cToken)) * borrowAmount) / 1e18;
            }
        }
        if (vars.sumCollateral > vars.totalBorrows) {
            return (vars.sumCollateral - vars.totalBorrows, 0);
        } else {
            return (0, vars.totalBorrows - vars.sumCollateral);
        }
    }
}
