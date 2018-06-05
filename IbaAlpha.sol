pragma solidity ^0.4.21;

/**
Template copied from:
https://github.com/ConsenSys/Token-Factory/blob/master/contracts/HumanStandardToken.sol
*/

import "./RealMath.sol";
import "./StandardToken.sol";


contract IbaAlphaToken is StandardToken {

    using RealMath for *;

    // Public variables of the token.
    string public name;
    string public symbol;
    uint256 public decimals;
    uint256 public unit;

    uint256 public mainSupply;    // main IBA supply pool
    uint256 public promo1Supply;  // promotion level 1 IBA supply pool
    uint256 public promo2Supply;  // promotion level 2 IBA supply pool
    uint256 public prizeSupply;   // prize IBA supply pool
    uint256 public develSupply;   // development IBA supply pool
    uint256 public cooperSupply;  // cooperations IBA supply pool
    uint256 public soldSupply;    // sold IBA token pool

    // Checking current value of the Company Supply is possible
    // by using the following method.
    function companySupply () public view returns (uint256) {
        return balances[owner];
    }

    address private owner;        // owner of the contract

    // Supply identifiers.
    uint8 constant MAIN_SUPPLY = 1;
    uint8 constant COMPANY_SUPPLY = 2;
    uint8 constant PROMO1_SUPPLY = 3;
    uint8 constant PROMO2_SUPPLY = 4;
    uint8 constant PRIZE_SUPPLY = 5;
    uint8 constant DEVEL_SUPPLY = 6;
    uint8 constant COOPER_SUPPLY = 7;

    // Shortcut values for Real Math operations.
    int128 REAL_TEN = int88(10).toReal();
    int128 REAL_1_ETHER = REAL_TEN.ipow(18);

    // Emitted after successful deposit of Ether transfered into IBA tokens.
    event Deposit (
        address indexed _to,
        uint256 indexed _ibaValue,
        uint256 indexed _etherValue,
        uint256 _promo1,
        uint256 _promo2
    );

    event Withdraw (
        address indexed _to,
        uint256 indexed _etherValue
    );

    // Emitted after IBA tokens has been successfully transfered
    // by contract owner between the supply pools.
    event SupplyTransfer (
        uint8 indexed _fromSupplyId,
        uint8 indexed _toSupplyId,
        uint256 indexed _value
    );

    // Only the contract owner will be allowed to successfully execute
    // function marked by this modifier.
    modifier ownerOnly () {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    // Returns true if _value of IBA wei can be withdrawn from the _supplyId.
    function _canTakeFromSupply (uint8 _supplyId, uint256 _value)
        private view returns (bool)
    {
        uint256 supply;

        if (_supplyId == MAIN_SUPPLY) {
            supply = mainSupply;
        } else if (_supplyId == COMPANY_SUPPLY) {
            supply = balances[owner];
        } else if (_supplyId == PROMO1_SUPPLY) {
            supply = promo1Supply;
        } else if (_supplyId == PROMO2_SUPPLY) {
            supply = promo2Supply;
        } else if (_supplyId == PRIZE_SUPPLY) {
            supply = prizeSupply;
        } else if (_supplyId == DEVEL_SUPPLY) {
            supply = develSupply;
        } else if (_supplyId == COOPER_SUPPLY) {
            supply = cooperSupply;
        } else {
            revert();
        }
        return supply >= _value;
    }

    // Withdraws _value of IBA wei from the _supplyId.
    // Returns true if succeeded.
    function _takeFromSupply (uint8 _supplyId, uint256 _value)
        private returns (bool)
    {
        if (!_canTakeFromSupply(_supplyId, _value)) {
            return false;
        }
        if (_supplyId == MAIN_SUPPLY) {
            mainSupply -= _value;
        } else if (_supplyId == COMPANY_SUPPLY) {
            balances[owner] -= _value;
        } else if (_supplyId == PROMO1_SUPPLY) {
            promo1Supply -= _value;
        } else if (_supplyId == PROMO2_SUPPLY) {
            promo2Supply -= _value;
        } else if (_supplyId == PRIZE_SUPPLY) {
            prizeSupply -= _value;
        } else if (_supplyId == DEVEL_SUPPLY) {
            develSupply -= _value;
        } else if (_supplyId == COOPER_SUPPLY) {
            cooperSupply -= _value;
        } else {
            // Unsupported supply id
            revert();
        }
        return true;
    }

    // Moves _value of IBA wei from _supplyId to the _to account.
    // Returns true if succeeded.
    function _giveFromSupply (address _to, uint8 _supplyId, uint256 _value)
        private returns (bool)
    {
        if (!_takeFromSupply(_supplyId, _value)) {
            return false;
        }
        if (_supplyId == MAIN_SUPPLY) {
            soldSupply += _value;
        }
        balances[_to] += _value;
        return true;
    }

    // Transfers _value of IBA wei between provided supply pools.
    // Returns true end emits SupplyTransfer event if succeeded.
    function supplyTransfer (
        uint8 _fromSupplyId, uint8 _toSupplyId, uint256 _value
    ) public ownerOnly returns (bool)
    {
        if (!_takeFromSupply(_fromSupplyId, _value)) {
            revert();
        }
        if (_toSupplyId == MAIN_SUPPLY) {
            mainSupply += _value;
        } else if (_toSupplyId == COMPANY_SUPPLY) {
            balances[owner] += _value;
        } else if (_toSupplyId == PROMO1_SUPPLY) {
            promo1Supply += _value;
        } else if (_toSupplyId == PROMO2_SUPPLY) {
            promo2Supply += _value;
        } else if (_toSupplyId == PRIZE_SUPPLY) {
            prizeSupply += _value;
        } else if (_toSupplyId == DEVEL_SUPPLY) {
            develSupply += _value;
        } else if (_toSupplyId == COOPER_SUPPLY) {
            cooperSupply += _value;
        } else {
            // Unsupported supply id
            revert();
        }
        emit SupplyTransfer(_fromSupplyId, _toSupplyId, _value);
        return true;
    }

    // Like supplyTransfer but _value is in IBA units.
    function supplyTransferUnits (
        uint8 _fromSupplyId, uint8 _toSupplyId, uint256 _value
    ) public ownerOnly returns (bool)
    {
        supplyTransfer(_fromSupplyId, _toSupplyId, _value * unit);
    }

    // Like balanceOf but returns balance in IBA units.
    function balanceOfUnits (address _user)
        public view returns (uint256 balance)
    {
        return balances[_user] / unit;
    }

    // Returns how many IBA wei can be currently bought for 1 Ether unit.
    // Performs Real Math calculations.
    function getBuyPrice () public view returns (int88) {
        int128 a; int128 b; int128 c; int128 d;

        /**
         * ibaWei = ( 1 * 10 ^18 ) / (
         *     ( 6666 / 10 ^7 ) *
         *     ( 1 000 000 015 / 10 ^9 ) ^( soldSupply / 10 ^18 )
         * )
         *
         * ibaWei = oneEther / (a * b)
         * a = 6666 / 10 ^7
         * b = c ^d
         * c = 1 000 000 015 / 10 ^9
         * d = soldSupply / 10 ^18
         */

        d = int88(soldSupply).toReal().div(REAL_TEN.ipow(18));
        c = int88(1000000015).toReal().div(REAL_TEN.ipow(9));
        b = c.ipow(int88(d.fromReal()));
        a = int88(6666).toReal().div(REAL_TEN.ipow(7));
        return REAL_1_ETHER.div(a.mul(b)).fromReal();
    }

    // Allows current user to send Ether
    // and transfer it into the the IBA tokens.
    function deposit () public payable {
        uint256 buyPrice = uint256(getBuyPrice());

        // ibaWei = buyPrice * depositedEtherWei / EtherUnit
        uint256 ibaWei = buyPrice * uint256(msg.value) / 1 ether;
        uint256 promo1Wei = ibaWei * 30 / 100;
        uint256 promo2Wei = ibaWei * 15 / 100;

        if (!_giveFromSupply(msg.sender, MAIN_SUPPLY, ibaWei)) {
            revert();
        }

        // Try to give additional promotion tokens if avalialbe in pool
        if (!_giveFromSupply(msg.sender, PROMO1_SUPPLY, promo1Wei)) {
            promo1Wei = 0;  // not enough promotion tokens in promo1 pool
            if (!_giveFromSupply(msg.sender, PROMO2_SUPPLY, promo2Wei)) {
                promo2Wei = 0;  // not enough promotion tokens in promo2 pool
            }
        }

        emit Deposit(msg.sender, ibaWei, msg.value, promo1Wei, promo2Wei);
    }

    // Launches deposit method if user sends Ether direcly to the contract.
    function () public payable {
        deposit();
    }

    // Returns current amount of Ether wei held by the contract.
    function contractEther () public view returns (uint256) {
        return address(this).balance;
    }

    // Like contractEther method but returns value in Ether units.
    function contractEtherUnits () public view returns (uint256) {
        return contractEther() / 1 ether;
    }

    // Withdraws at most _etherWei amount of Ether wei from the contract
    // ant transfers that Ether to the sender account.
    // Only the contract owner is able to perform this operation.
    function withdraw (uint256 _etherWei)
        public ownerOnly returns (uint256)
    {
        uint256 amount = _etherWei;

        if (address(this).balance < amount) {
            amount = address(this).balance;
        }
        if (amount > 0) {
            address(msg.sender).transfer(amount);
            emit Withdraw(msg.sender, amount);
        }
        return amount;
    }

    // Like withdraw method but in Ether units.
    function withdrawUnits (uint256 _value)
        public ownerOnly returns (uint256)
    {
        return withdraw(_value * 1 ether);
    }

    // Creates new IBA contract.
    constructor () public {
        name = 'IBA alpha';
        symbol = 'IBAa';
        decimals = 18;
        unit = 10 ** decimals;  // 1 IBA unit is that much IBA wei
        owner = msg.sender;     // owner of the contract

        totalSupply = 300 * 10 ** 6 * unit;  // 300 million IBA - hard cap
        mainSupply = totalSupply;
        soldSupply = 0;
        promo2Supply = 0;
        prizeSupply = 0;

        // Give 40% of the totalSupply to the contract owner.
        balances[owner] = 40 * totalSupply / 100;

        // Give 3% of the totalSupply to the PROMO1_SUPPLY.
        // At the end of PROMO 1 STAGE remaining funds will be manually
        // transferred from promo1Supply into the promo2Supply pool and finally
        // at the end of PROMO 2 STAGE into the prizeSupply.
        promo1Supply = 3 * totalSupply / 100;

        // Give 5% of the totalSupply to the DEVEL_SUPPLY
        develSupply = 5 * totalSupply / 100;

        // Give 3% of the totalSupply to the COOPER_SUPPLY
        cooperSupply = 3 * totalSupply / 100;

        // update mainSupply to reflect changes
        mainSupply -=
            balances[owner] + promo1Supply + develSupply + cooperSupply;
    }
}
