// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PoshCoin is ERC20, Ownable, AccessControl, Pausable {
    using SafeMath for uint256;

    uint8 public decimal = 18;

    uint256 public taxFee = 0;

    address public marketingWalletAddress;

    uint256 public maxTxAmount = 10000000 * (10**18);

    uint256 public maxAmountHold = 100000000 * (10**18);

    mapping(address => bool) public _isBlacklisted;
    // exlcude from fees and max transaction amount
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isWhiteListed;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);

    event WhitelistedWallet(address indexed account, bool isExcluded);

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address ownerAddress,
        address _marketingWalletAddress
    ) ERC20(name, symbol) {
        _mint(ownerAddress, totalSupply * (10**decimal));
        _setupRole(DEFAULT_ADMIN_ROLE, ownerAddress);
        transferOwnership(ownerAddress);
        marketingWalletAddress = _marketingWalletAddress;
    }

    function blacklistAddress(address account, bool value) external onlyOwner {
        require(account != owner(), "Shouldn't be owner address");
        _isBlacklisted[account] = value;
    }

    function setMaxTxAmount(uint256 newAmount) external onlyOwner {
        // Min it should be 1% of the total supply. 
        uint256 minAmount = totalSupply() * 1/100;
        require(newAmount > minAmount, "Min amount should be 1%");
        maxTxAmount = newAmount;
    }

    function setMaxAmountHold(uint256 newAmount) external onlyOwner {
      uint256 minAmount = totalSupply() * 10/100;
        require(newAmount > minAmount, "Min amount should be 10%");
        maxAmountHold = newAmount;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimal;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "PSCN: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function whitelistWallet(address account, bool excluded) public onlyOwner {
        require(
            _isWhiteListed[account] != excluded,
            "PSCN: Account is already the value of whitelisted"
        );
        _isWhiteListed[account] = excluded;

        emit WhitelistedWallet(account, excluded);
    }

    function isWhiteListedWallet(address account) public view returns (bool) {
        return _isWhiteListed[account];
    }

    function setTaxFee(uint256 _taxFee) external onlyOwner {
        require(_taxFee < 18, "Tax fee should not be more than 18%.");
        taxFee = _taxFee;
    }

    function setMarketWalletAddress(address _marketingWalletAddress)
        external
        onlyOwner
    {
        require(
            marketingWalletAddress != _marketingWalletAddress,
            "Should not be same wallet"
        );
        marketingWalletAddress = _marketingWalletAddress;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        bool takeFee = true;
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(
            !_isBlacklisted[from] && !_isBlacklisted[to],
            "Blacklisted address"
        );
        if (from == owner() || to == owner() || isWhiteListedWallet(from) || isWhiteListedWallet(to)) {
            takeFee = false;
        } else { 
              require(
                amount <= maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
            uint256 newBalance = balanceOf(to) + amount;

            require(
                newBalance <= maxAmountHold,
                "Your balance is exceeded the limit to hold."
            );
        }
        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }
        if (takeFee) {
            uint256 fees = amount.mul(taxFee).div(100);
            amount = amount.sub(fees);
            super._transfer(from, marketingWalletAddress, fees);
        }
        super._transfer(from, to, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}