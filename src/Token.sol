// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IToken} from "./interfaces/IToken.sol";

/**
 * @title Token Contract
 * @notice Implements ERC20 token with permit functionality
 */
contract Token is IToken, ERC20Permit {
    address private _factory;
    bool private _minted;
    string public tokenURI;
    address private gNad;

    constructor(string memory name, string memory symbol, string memory _tokenURI, address _gNad)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        tokenURI = _tokenURI;
        _minted = false;
        _factory = msg.sender;
        gNad = _gNad;
    }

    function mint(address _curve) external {
        require(msg.sender == _factory, "Invalid token factory address");
        require(!_minted, "Invalid: Token can mint only one time");
        require(totalSupply() == 0, "Invalid: Token can mint only one time");
        _mint(_curve, 10 ** 27); // Decimals is 18, So total supply is 1B
        _minted = true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    function permitTypeHash() public pure virtual returns (bytes32 x) {
        bytes memory _input = "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)";
        assembly {
            x := keccak256(add(_input, 0x20), mload(_input))
        }
    }

    function transfer(address to, uint256 value) public virtual override(ERC20, IERC20) returns (bool) {
        _transfer(msg.sender, to, value);

        return true;
    }
}
