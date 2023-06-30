//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./ERC20.sol";
import "./CTokenInterface.sol";
import "./ComptrollerInterface.sol";
import "./InterestRateInterface.sol";

abstract contract CToken is ERC20, CTokenInterface {
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    // Mapping of account addresses to outstanding borrow balances
    mapping(address => BorrowSnapshot) internal accountBorrows;
    // uint256 supplyIndex;
    uint256 initialExchangeRate;
    uint256 lastBlockNumber;
    uint256 totalBorrows;
    uint256 borrowIndex;
    uint256 reserveFactor;
    uint256 totalReserves;
    address underlying;
    address admin;
    uint256 constant borrowRateMax = 0.0005e16;

    IERC20 token;
    ComptrollerInterface comptroller;
    InterestRateModelInterface interestRateModel;

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        ComptrollerInterface _comptroller,
        IERC20 _token,
        InterestRateModelInterface _interestRateModel,
        uint256 _reserveFactor
    ) public {
        tokenName = _name;
        tokenSymbol = _symbol;
        comptroller = _comptroller;
        token = _token;
        borrowIndex = 1e18;
        underlying = _underlying;
        interestRateModel = _interestRateModel;
        reserveFactor = _reserveFactor;
        admin = msg.sender;
    }

    function getBorrowBalance(address account) external returns (uint256) {
        accrueInterest();
        return getBorrowBalanceInternal(account);
    }

    function mintToken(uint256 mintAmount) external {
        accrueInterest();

        bool status = comptroller.mintAllowed(address(this));
        require(status, "can not mint cTokens now");
        doTransferIn(mintAmount);
        uint256 mintedCTokens = (mintAmount / getExchangeRateInternal()) * 1e18;
        tokenBalance[msg.sender] += mintedCTokens;
        totalSupply += mintedCTokens;
        emit Mint(msg.sender, mintedCTokens);
    }

    function redeemToken(uint256 redeemTokens) external {
        accrueInterest();

        bool status = comptroller.redeemAllowed(
            address(this),
            msg.sender,
            redeemTokens
        );
        require(status == true, "can not redeem tokens");
        require(tokenBalance[msg.sender] >= redeemTokens, "NOT_ENOUGH_BALANCE");

        totalSupply -= redeemTokens;
        tokenBalance[msg.sender] -= redeemTokens;

        uint256 redeemAmount = redeemTokens * getExchangeRateInternal();

        doTransferOut(redeemAmount);
        emit Redeem(msg.sender, redeemTokens);
    }

    function borrow(uint256 borrowAmount) external {
        accrueInterest();
        bool status = comptroller.borrowAllowed(
            address(this),
            msg.sender,
            borrowAmount
        );

        require(status, "borrow not allowed");
        require(getCashPrior() > borrowAmount, "insufficient underlying cash");

        uint accountBorrowsPrev = getBorrowBalanceInternal(msg.sender);
        uint accountBorrowsNew = accountBorrowsPrev + borrowAmount;
        uint totalBorrowsNew = totalBorrows + borrowAmount;

        accountBorrows[msg.sender].principal = accountBorrowsNew;
        accountBorrows[msg.sender].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        doTransferOut(borrowAmount);

        emit Borrow(
            msg.sender,
            borrowAmount,
            accountBorrowsNew,
            totalBorrowsNew
        );
    }

    function repayBorrow(uint256 repayAmount) external {
        accrueInterest();
        bool status = comptroller.repayAllowed(address(this));
        require(status, "REPAY_NOT_ALLOWED");
        uint256 currentBorrowBalance = getBorrowBalanceInternal(msg.sender);
        require(
            currentBorrowBalance >= repayAmount,
            "repay amount greater than borrowed amount"
        );

        doTransferIn(repayAmount);

        uint256 accountBorrowsNew = currentBorrowBalance - repayAmount;
        uint256 totalBorrowsNew = totalBorrows - repayAmount;

        accountBorrows[msg.sender].principal = accountBorrowsNew;
        accountBorrows[msg.sender].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        emit RepayBorrow(
            msg.sender,
            repayAmount,
            accountBorrowsNew,
            totalBorrowsNew
        );
    }

    function accrueInterest() internal {
        uint currentBlockNumber = block.number;
        uint blockNumberPrev = lastBlockNumber;

        if (blockNumberPrev == currentBlockNumber) {
            return;
        }

        uint256 cashPrev = getCashPrior();
        uint256 borrowsPrev = totalBorrows;
        uint256 reservesPrev = totalReserves;
        uint256 borrowIndexPrev = borrowIndex;

        uint borrowRate = interestRateModel.getBorrowRate(
            cashPrev,
            borrowsPrev,
            reservesPrev
        );
        require(borrowRate <= borrowRateMax, "borrow rate is very high");

        uint blockDelta = currentBlockNumber - blockNumberPrev;

        uint256 simpleInterestFactor = borrowRate * blockDelta;
        uint256 interestAccumulated = simpleInterestFactor * borrowsPrev;
        totalBorrows = interestAccumulated + borrowsPrev;
        totalReserves = reserveFactor * interestAccumulated + reservesPrev;
        borrowIndex = simpleInterestFactor * borrowIndexPrev + borrowIndexPrev;
        lastBlockNumber = currentBlockNumber;

        emit AccrueInterest(
            cashPrev,
            interestAccumulated,
            borrowIndex,
            totalBorrows
        );
    }

    function getExchangeRate() external returns (uint256) {
        accrueInterest();
        return getExchangeRateInternal();
    }

    function getExchangeRateInternal() internal view returns (uint256) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            return 1;
        } else {
            uint256 totalCash = getCashPrior();
            uint256 cashPlusBorrowsMinusReserves = totalCash +
                totalBorrows -
                totalReserves;
            uint256 exchangeRate = (cashPlusBorrowsMinusReserves * 1e18) /
                _totalSupply;

            return exchangeRate;
        }
    }

    function getCashPrior() internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function setReserveFactor(uint256 _newReserveFactor) external {
        require(msg.sender == admin, "not authorized to set reserve factor");
        reserveFactor = _newReserveFactor;
    }

    function getAccountSnapshot(
        address account
    ) external view returns (uint, uint, uint) {
        return (
            tokenBalance[account],
            getBorrowBalanceInternal(account),
            getExchangeRateInternal()
        );
    }

    function getBorrowBalanceInternal(
        address account
    ) internal view returns (uint256) {
        BorrowSnapshot storage borrowSnapshot = accountBorrows[account];

        if (borrowSnapshot.principal == 0) {
            return 0;
        }
        uint256 principalTimesIndex = borrowSnapshot.principal * borrowIndex;

        return principalTimesIndex / borrowSnapshot.interestIndex;
    }

    function doTransferIn(uint256 amount) internal {
        token.transferFrom(msg.sender, address(this), amount);
    }

    function doTransferOut(uint256 amount) internal {
        token.transfer(msg.sender, amount);
    }
}
