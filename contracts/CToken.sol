//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./ERC20.sol";
import "./CTokenInterface.sol";
import "./ComptrollerInterface.sol";

abstract contract CToken is ERC20, CTokenInterface {
    uint256 supplyIndex;
    uint256 initialExchangeRate;
    uint256 lastBlockNumber;
    uint256 totalBorrows;
    uint256 borrowIndex;
    uint256 reserveFactor;
    uint256 totalReserves;
    address underlying;
    uint256 constant borrowRateMax = 0.0005e16;

    IERC20 token;
    ComptrollerInterface comptroller;

    function initialize(string calldata _name, string calldata _symbol,address _underlying,  ComptrollerInterface _comptroller, IERC20 _token) public {
        tokenName = _name;
        tokenSymbol = _symbol;
        comptroller = _comptroller;
        token = _token;
        borrowIndex = 1e18;
        underlying = _underlying;
    }

    function mintToken(uint256 mintAmount) external {
        accrueInterest();

        bool status = comptroller.mintAllowed();
        require(status, "can not mint cTokens now");
        doTransferIn(mintAmount);
        uint256 mintedCTokens = (mintAmount / exchangeRateStoredInternal()) * 1e18;
        tokenBalance[msg.sender] += mintedCTokens;
        totalSupply += mintedCTokens;
        emit Mint(msg.sender, mintedCTokens);
    }

    function redeemToken(uint256 redeemTokens) external {
        accrueInterest();

        bool status = comptroller.redeemAllowed();
        require(status == true, "can not redeem tokens");
        require(accountTokens[msg.sender] < _redeemTokens, "NOT_ENOUGH_BALANCE");

        totalSupply -= _redeemTokens;
        accountTokens[redeemer] -= redeemTokens;

        uint256 redeemAmount = redeemTokens * currentExchangeRate();

        doTransferOut(redeemAmount);
        emit Redeem(redeemer, _redeemTokens);
    }

    

    function  accrueInterest() internal {
        uint currentBlockNumber = block.number;
        uint blockNumberPrev = lastBlockNumber;

        if (blockNumberPrev == currentBlockNumber) {
            return;
        }

        uint256 cashPrev = getCashPrior();
        uint256 borrowsPrev = totalBorrows;
        uint256 reservesPrev = totalReserves;
        uint256 borrowIndexPrev = borrowIndex;

        uint borrowRate = interestRateModel.getBorrowRate(cashPrev, borrowsPrev, reservesPrev);
        require(borrowRate <= borrowRateMax, "borrow rate is very high");

        uint blockDelta = currentBlockNumber - accrualBlockNumberPrior;

        uint256 simpleInterestFactor = borrowRate * blockDelta;
        uint256 interestAccumulated = simpleInterestFactor * borrowsPrev;
        totalBorrows = interestAccumulated + borrowsPrev;
        totalReserves = reserveFactor * interestAccumulated + reservesPrev;
        borrowIndex = simpleInterestFactor *  borrowIndexPrev + borrowIndexPrev;
        lastBlockNumber = currentBlockNumber;

        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
    }

    function doTransferIn(uint256 amount) internal {
        token.transferFrom(msg.sender, address(this), amount);
    }

    function doTransferOut(uint256 amount) internal {
        token.transfer(msg.sender, amount);
    }

    function getExchangeRate() virtual internal view returns (uint128) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return initialExchangeRateMantissa;
        } else {
            uint256 totalCash = getCashPrior();
            uint256 cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;
            uint256 exchangeRate = cashPlusBorrowsMinusReserves * expScale / _totalSupply;

            return exchangeRate;
        }
    }

    function getCashPrior() internal returns(uint256){
        return token.balanceOf(address(this));
    }

    function setReserveFactor(uint256 _newReserveFactor) external {
        require(msg.sender == admin, "not authorized to set reserve factor");
        reserveFactor = _newReserveFactor;
    }
}