//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./ComptrollerInterface.sol";
import "./CToken.sol";

contract Comptroller is ComptrollerInterface {

    mapping(address => Market) markets;
    mapping(address => CToken[]) accountAssets;

    function joinMarket(CToken cToken) external {
        require(markets[address(cToken)].isListed, "market is not listed");
        markets[address(cToken)].accountMembership[msg.sender] = true;
        accountAssets[msg.sender].push(cToken);
    }

    function checkMembership(address account, CToken cToken) external view returns (bool) {
        return markets[address(cToken)].accountMembership[account];
    }
    
    function exitMarket(address cToken) external {

    }

    function mintAllowed() external returns(bool status){
        if (!markets[msg.sender].isListed) {
            return false;
        }

        return true;
    }

    function redeemAllowed(address cToken, address account, uint256 tokensIn) external returns (bool){
        return redeemAllowedInternal(cToken, account, tokensIn);
    }

    function redeemAllowedInternal(address cToken, address redeemer, uint256 tokensIn) internal returns (bool status){
        if (!markets[cToken].isListed) {
            return false;
        }

        if (!markets[cToken].accountMembership[redeemer]) {
            return true;
        }

    // have to work on it   (Error err, , uint shortfall) = getHypotheticalAccountLiquidityInternal(redeemer, CToken(cToken), redeemTokens, 0);
        if (err != Error.NO_ERROR) {
            return false;
        }
        if (shortfall > 0) {
            return false;
        }

        return true;
    }

    function borrowAllowed() external returns(bool status){

    }
    
    

    function repayAllowed() external returns(bool status){

    }
}