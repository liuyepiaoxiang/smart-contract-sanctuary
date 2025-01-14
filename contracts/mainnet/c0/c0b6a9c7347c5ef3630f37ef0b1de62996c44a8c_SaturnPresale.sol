pragma solidity ^0.4.18;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract ERC223 {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);

  function name() constant returns (string _name);
  function symbol() constant returns (string _symbol);
  function decimals() constant returns (uint8 _decimals);
  function totalSupply() constant returns (uint256 _supply);

  function transfer(address to, uint value) returns (bool ok);
  function transfer(address to, uint value, bytes data) returns (bool ok);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event ERC223Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);
}

contract ContractReceiver {
  function tokenFallback(address _from, uint _value, bytes _data);
}

contract ERC223Token is ERC223 {
  using SafeMath for uint;

  mapping(address => uint) balances;

  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;


  // Function to access name of token .
  function name() constant returns (string _name) {
      return name;
  }
  // Function to access symbol of token .
  function symbol() constant returns (string _symbol) {
      return symbol;
  }
  // Function to access decimals of token .
  function decimals() constant returns (uint8 _decimals) {
      return decimals;
  }
  // Function to access total supply of tokens .
  function totalSupply() constant returns (uint256 _totalSupply) {
      return totalSupply;
  }

  // Function that is called when a user or another contract wants to transfer funds .
  function transfer(address _to, uint _value, bytes _data) returns (bool success) {
    if(isContract(_to)) {
        return transferToContract(_to, _value, _data);
    }
    else {
        return transferToAddress(_to, _value, _data);
    }
}

  // Standard function transfer similar to ERC20 transfer with no _data .
  // Added due to backwards compatibility reasons .
  function transfer(address _to, uint _value) returns (bool success) {

    //standard function transfer similar to ERC20 transfer with no _data
    //added due to backwards compatibility reasons
    bytes memory empty;
    if(isContract(_to)) {
        return transferToContract(_to, _value, empty);
    }
    else {
        return transferToAddress(_to, _value, empty);
    }
}

//assemble the given address bytecode. If bytecode exists then the _addr is a contract.
  function isContract(address _addr) private returns (bool is_contract) {
      uint length;
      assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        if(length>0) {
            return true;
        }
        else {
            return false;
        }
    }

  //function that is called when transaction target is an address
  function transferToAddress(address _to, uint _value, bytes _data) private returns (bool success) {
    if (balanceOf(msg.sender) < _value) revert();
    balances[msg.sender] = balanceOf(msg.sender).sub(_value);
    balances[_to] = balanceOf(_to).add(_value);
    Transfer(msg.sender, _to, _value);
    ERC223Transfer(msg.sender, _to, _value, _data);
    return true;
  }

  //function that is called when transaction target is a contract
  function transferToContract(address _to, uint _value, bytes _data) private returns (bool success) {
    if (balanceOf(msg.sender) < _value) revert();
    balances[msg.sender] = balanceOf(msg.sender).sub(_value);
    balances[_to] = balanceOf(_to).add(_value);
    ContractReceiver reciever = ContractReceiver(_to);
    reciever.tokenFallback(msg.sender, _value, _data);
    Transfer(msg.sender, _to, _value);
    ERC223Transfer(msg.sender, _to, _value, _data);
    return true;
  }


  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }
}

contract SaturnPresale is ContractReceiver {
  using SafeMath for uint256;

  bool public active = false;
  mapping(address=>uint256) private purchased;
  mapping(address=>uint256) private lockup;

  address public tokenAddress;

  uint256 private priceDiv;
  uint256 private purchaseLimit;
  uint256 public hardCap;
  uint256 public sold;

  address private owner;
  address private treasury;

  event Activated(uint256 time);
  event Finished(uint256 time);
  event Purchase(address indexed purchaser, uint256 amount, uint256 purchasedAt, uint256 redeemAt);

  function SaturnPresale(address token, address ethRecepient, uint256 minPurchase, uint256 presaleHardCap, uint256 price) public {
    tokenAddress  = token;
    priceDiv      = price;
    owner         = msg.sender;
    purchaseLimit = minPurchase;
    treasury      = ethRecepient;
    hardCap       = presaleHardCap;
  }

  function tokenFallback(address /* _from */, uint _value, bytes /* _data */) public {
    // Accept only SATURN ERC223 token
    if (msg.sender != tokenAddress) { revert(); }
    // If the Presale is active do not accept incoming transactions
    if (active) { revert(); }
    // Only accept one transaction in the amount of
    if (_value != hardCap) { revert(); }

    active = true;
    Activated(now);
  }

  function balanceOf(address person) constant public returns (uint balance) {
    return purchased[person];
  }

  function lockupOf(address person) constant public returns (uint timestamp) {
    return lockup[person];
  }

  function () external payable {
    buyTokens();
  }

  function buyTokens() payable public {
    if (!active) { revert(); }
    if (msg.value < purchaseLimit) { revert(); }

    uint256 purchasedAmount = msg.value.div(priceDiv);
    if (purchasedAmount == 0) { revert(); }
    if (purchasedAmount > hardCap - sold) { revert(); }

    if (lockup[msg.sender] == 0) {
      lockup[msg.sender] = now + 1 years;
    }
    purchased[msg.sender] = purchased[msg.sender] + purchasedAmount;
    sold = sold + purchasedAmount;
    treasury.transfer(msg.value);
    Purchase(msg.sender, purchasedAmount, now, lockup[msg.sender]);
  }

  function endPresale() public {
    // only the creator of the smart contract
    // can end the crowdsale prematurely
    if (msg.sender != owner) { revert(); }
    // can only stop an active crowdsale
    if (!active) { revert(); }
    _end();
  }

  function redeem() public {
    if (purchased[msg.sender] == 0) { revert(); }
    if (now < lockup[msg.sender]) { revert(); }

    uint256 withdrawal = purchased[msg.sender];
    purchased[msg.sender] = 0;

    ERC223 token = ERC223(tokenAddress);
    token.transfer(msg.sender, withdrawal);
  }

  function _end() private {
    // if there are any tokens remaining - return them to the owner
    if (sold < hardCap) {
      ERC223 token = ERC223(tokenAddress);
      token.transfer(treasury, hardCap.sub(sold));
    }
    active = false;
    Finished(now);
  }
}