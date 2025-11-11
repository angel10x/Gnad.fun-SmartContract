// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {
    IERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WGnad is ERC20Permit {
    constructor() ERC20("Wrapped GoMonad Token", "WGnad") ERC20Permit("WGNAD") {}

    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }

    event Deposit(address indexed to, uint256 amount);
    event Withdrawal(address indexed from, uint256 amount);

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function nonces(
        address owner
    ) public view virtual override(ERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    function permitTypeHash() public pure virtual returns (bytes32) {
        return
            keccak256(
                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
            );
    }
}
