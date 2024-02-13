//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface CTokenInterface {
    event Mint(address minter, uint256 mintedTokens);
    event Redeem(address redeemer, uint256 redeemTokens);
    event AccrueInterest(
        uint256 cashPrior,
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event Borrow(
        address borrower,
        uint256 borrowAmount,
        uint256 accountBorrowsNew,
        uint256 totalBorrowsNew
    );
    event RepayBorrow(
        address payer,
        uint256 repayAmount,
        uint256 accountBorrowsNew,
        uint256 totalBorrowsNew
    );

    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    function mintToken(uint256 mintAmount) external;

    function redeemToken(uint256 redeemTokens) external;

    function borrow(uint256 borrowAmount) external;

    function repayBorrow(uint256 repayAmount) external;

    function isCtoken() external returns (bool);
}
