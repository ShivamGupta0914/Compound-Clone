//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "./Interfaces/IERC20.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 * which implements the Fungible ERC20 token.
 */

contract ERC20 is IERC20 {

    uint256 public totalSupply;
    string internal tokenName;
    string internal tokenSymbol;
    mapping(address => uint256) internal tokenBalance;
    mapping(address => mapping(address => uint256)) internal approvalBalance;

    /**
     * @dev this function sends token from msg.sender address to _to address with amount _amount
     * emits a transfer event.
     * @param _to is the address to which token is transferred.
     * @param _amount is the amount of token to be transferred.
     * @return boolean value.
     */
    function transfer(address _to, uint256 _amount) external returns (bool) {
        require(_to != address(0), "can not send tokens to zero address");
        require(tokenBalance[msg.sender] >= _amount, "Insufficient amount");
        tokenBalance[msg.sender] -= _amount;
        tokenBalance[_to] += _amount;
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @dev this function approves another account to use their token, msg.sender will call this function,
     * emits a approve event.
     * @param _spender is the account which will be approved.
     * @param _amount is the amount of tokens which will be approved.
     * @return boolean value.
     */
    function approve(
        address _spender,
        uint256 _amount
    ) external returns (bool) {
        require(msg.sender != _spender, "Can not approve Yourself");
        approvalBalance[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev this function transfers token from owner account to another acoount, only approved accounts can use this function,
     * emits a transfer event.
     * @param _from is the account from which tokens will be transferred.
     * @param _to is the account to which tokens will be transferred.
     * @param _amount is the amount of tokens which will be transferred.
     * @return boolean value.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool) {
        require(
            _from != address(0) && _to != address(0),
            "can not transfer or send to zero address"
        );
        require(
            tokenBalance[_from] >= _amount,
            "from does not have sufficient balance"
        );
        require(
            approvalBalance[_from][msg.sender] >= _amount,
            "Not Authorized Or Insufficient Balance"
        );
        approvalBalance[_from][msg.sender] -= _amount;
        tokenBalance[_from] -= _amount;
        tokenBalance[_to] += _amount;
        emit Transfer(_from, _to, _amount);
        return true;
    }

    /**
     * @dev gives information about the number of tokens of an address.
     * @param _account of which tokens to be find.
     * @return balance of token in that account.
     */
    function balanceOf(address _account) external view returns (uint256) {
        return tokenBalance[_account];
    }

    /**
     * @dev gives information about the tokens that are on approved to an account.
     * @param _owner is the account of owner.
     * @param _spender is the account which is approved.
     * @return number of tokens which are approved.
     */
    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256) {
        return approvalBalance[_owner][_spender];
    }

    /**
     * @dev this function is used to get name of token.
     * @return name of token.
     */
    function name() external view returns (string memory) {
        return tokenName;
    }

    /**
     * @dev this function is used to get symbol of token.
     * @return symbol of token.
     */
    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }
}
