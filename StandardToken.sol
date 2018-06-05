pragma solidity ^0.4.21;

/*
Template copied from:
https://github.com/ConsenSys/Token-Factory/blob/master/contracts/StandardToken.sol

This implements ONLY the standard functions and NOTHING else.
For a token like you would want to deploy in something like Mist, see HumanStandardToken.sol.

If you deploy this, you won't have anything useful.

Implements ERC 20 Token standard: https://github.com/ethereum/EIPs/issues/20
.*/


contract StandardToken {

    // An array holding IBA balances for all user accounts.
    mapping (address => uint256) internal balances;

    // An array holding allowances to make transfers between accounts.
    mapping (address => mapping (address => uint256)) internal allowed;

    // Total IBA unit supply (hard cap)
    uint256 public totalSupply;

    // Emitted after successfull transfer.
    event Transfer (
        address indexed _from, address indexed _to, uint256 _value
    );

    // Emitted after _owner allows _spender to transfer _value of IBA wei.
    event Approval (
        address indexed _owner, address indexed _spender, uint256 _value
    );

    // Allows user to transfer _value of IBA wei to the _to account.
    function transfer (address _to, uint256 _value)
        public returns (bool success)
    {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            emit Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    // Allows any user to execute transfer between accounts,
    // where allowance for given _value has been set between users.
    function transferFrom (address _from, address _to, uint256 _value)
        public returns (bool success)
    {
        if (
            balances[_from] >= _value && allowed[_from][msg.sender] >=
            _value && _value > 0
        ) {
            balances[_to] += _value;
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            emit Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    // Returns balance of IBA wei for given _user.
    function balanceOf (address _user) public view returns (uint256 balance) {
        return balances[_user];
    }

    // Sets allowance to execute transfer between current users
    // and _spender account for given _value.
    function approve (address _spender, uint256 _value)
        public returns (bool success)
    {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // Returns value of transfer allowance set between _owner and _spender.
    function allowance (address _owner, address _spender)
        public view returns (uint256 remaining)
    {
        return allowed[_owner][_spender];
    }
}
