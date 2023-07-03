//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./ERC20.sol";

contract Qod is ERC20 {

    uint8 constant public DECIMALS = 18;

    constructor(string memory _name, string memory _symbol) {
        tokenName = _name;
        tokenSymbol = _symbol;
    }

    function mint(uint256 tokenAmount) external {
        tokenBalance[msg.sender] += tokenAmount;
    }

    function burn(uint256 tokenAmount) external {
        tokenBalance[msg.sender] -= tokenAmount;
    }

}