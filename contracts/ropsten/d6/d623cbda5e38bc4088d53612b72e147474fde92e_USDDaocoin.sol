/**
 *Submitted for verification at Etherscan.io on 2019-07-10
*/

pragma solidity 0.5.10;

/**
 * @dev Wrappers over Solidity&#39;s arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it&#39;s recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity&#39;s `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity&#39;s `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity&#39;s `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring &#39;a&#39; not being zero, but the
        // benefit is lost if &#39;b&#39; is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity&#39;s `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity&#39;s `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller&#39;s account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller&#39;s tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender&#39;s allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller&#39;s
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account&#39;s access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

/**
 * @dev Multiownable smart contract
 * which allows to many ETH wallets to manage main smart contract.
 */
contract Multiownable {
    // VARIABLES

    uint256 internal _ownersGeneration;
    uint256 internal _howManyOwnersDecide;
    address[] internal _owners;
    bytes32[] internal _allOperations;
    address internal _insideCallSender;
    uint256 internal _insideCallCount;

    // Reverse lookup tables for owners and allOperations
    mapping(address => uint256) public ownersIndices; // Starts from 1
    mapping(bytes32 => uint256) public allOperationsIndicies;

    // Owners voting mask per operations
    mapping(bytes32 => uint256) public votesMaskByOperation;
    mapping(bytes32 => uint256) public votesCountByOperation;

    // EVENTS

    event OwnershipTransferred(address[] previousOwners, uint256 howManyOwnersDecide, address[] newOwners, uint256 newHowManyOwnersDecide);
    event OperationCreated(bytes32 operation, uint256 howMany, uint256 ownersCount, address proposer);
    event OperationUpvoted(bytes32 operation, uint256 votes, uint256 howMany, uint256 ownersCount, address upvoter);
    event OperationPerformed(bytes32 operation, uint256 howMany, uint256 ownersCount, address performer);
    event OperationDownvoted(bytes32 operation, uint256 votes, uint256 ownersCount,  address downvoter);
    event OperationCancelled(bytes32 operation, address lastCanceller);
    
    // ACCESSORS

    function isOwner(address wallet) external view returns (bool) {
        return ownersIndices[wallet] > 0;
    }

    function ownersCount() external view returns (uint256) {
        return _owners.length;
    }

    function allOperationsCount() external view returns (uint256) {
        return _allOperations.length;
    }

    // MODIFIERS

    /**
     * @dev Allows to perform method by any of the owners
     */
    modifier onlyAnyOwner {
        if (checkHowManyOwners(1)) {
            bool update = (_insideCallSender == address(0));
            if (update) {
                _insideCallSender = msg.sender;
                _insideCallCount = 1;
            }
            _;
            if (update) {
                _insideCallSender = address(0);
                _insideCallCount = 0;
            }
        }
    }

    /**
     * @dev Allows to perform method only after many owners call it with the same arguments
     */
    modifier onlyManyOwners {
        if (checkHowManyOwners(_howManyOwnersDecide)) {
            bool update = (_insideCallSender == address(0));
            if (update) {
                _insideCallSender = msg.sender;
                _insideCallCount = _howManyOwnersDecide;
            }
            _;
            if (update) {
                _insideCallSender = address(0);
                _insideCallCount = 0;
            }
        }
    }

    /**
     * @dev Allows to perform method only after all owners call it with the same arguments
     */
    modifier onlyAllOwners {
        if (checkHowManyOwners(_owners.length)) {
            bool update = (_insideCallSender == address(0));
            if (update) {
                _insideCallSender = msg.sender;
                _insideCallCount = _owners.length;
            }
            _;
            if (update) {
                _insideCallSender = address(0);
                _insideCallCount = 0;
            }
        }
    }

    /**
     * @dev Allows to perform method only after some owners call it with the same arguments
     */
    modifier onlySomeOwners(uint256 howMany) {
        require(howMany > 0, "onlySomeOwners: howMany argument is zero");
        require(howMany <= _owners.length, "onlySomeOwners: howMany argument exceeds the number of owners");
        
        if (checkHowManyOwners(howMany)) {
            bool update = (_insideCallSender == address(0));
            if (update) {
                _insideCallSender = msg.sender;
                _insideCallCount = howMany;
            }
            _;
            if (update) {
                _insideCallSender = address(0);
                _insideCallCount = 0;
            }
        }
    }

    // CONSTRUCTOR

    constructor() public {
        _owners.push(msg.sender);
        ownersIndices[msg.sender] = 1;
        _howManyOwnersDecide = 1;
    }

    // INTERNAL METHODS

    /**
     * @dev onlyManyOwners modifier helper
     */
    function checkHowManyOwners(uint256 howMany) internal returns (bool) {
        if (_insideCallSender == msg.sender) {
            require(howMany <= _insideCallCount, "checkHowManyOwners: nested owners modifier check require more owners");
            return true;
        }

        uint256 ownerIndex = ownersIndices[msg.sender] - 1;
        require(ownerIndex < _owners.length, "checkHowManyOwners: msg.sender is not an owner");

        bytes32 operation = keccak256(abi.encodePacked(msg.data, _ownersGeneration));
        require((votesMaskByOperation[operation] & (2 ** ownerIndex)) == 0, "checkHowManyOwners: owner already voted for the operation");

        votesMaskByOperation[operation] |= (2 ** ownerIndex);
        uint256 operationVotesCount = votesCountByOperation[operation] + 1;
        votesCountByOperation[operation] = operationVotesCount;

        if (operationVotesCount == 1) {
            allOperationsIndicies[operation] = _allOperations.length;
            _allOperations.push(operation);
            emit OperationCreated(operation, howMany, _owners.length, msg.sender);
        }

        emit OperationUpvoted(operation, operationVotesCount, howMany, _owners.length, msg.sender);

        // If enough owners confirmed the same operation
        if (votesCountByOperation[operation] == howMany) {
            deleteOperation(operation);
            emit OperationPerformed(operation, howMany, _owners.length, msg.sender);
            return true;
        }

        return false;
    }

    /**
     * @dev Used to delete cancelled or performed operation
     * @param operation defines which operation to delete
     */
    function deleteOperation(bytes32 operation) internal {
        uint256 index = allOperationsIndicies[operation];

        if (index < _allOperations.length - 1) { // Not last
            _allOperations[index] = _allOperations[_allOperations.length - 1];
            allOperationsIndicies[_allOperations[index]] = index;
        }

        _allOperations.length--;

        delete votesMaskByOperation[operation];
        delete votesCountByOperation[operation];
        delete allOperationsIndicies[operation];
    }

    // PUBLIC METHODS

    /**
     * @dev Allows owners to change their mind by cacnelling votesMaskByOperation operations
     * @param operation defines which operation to delete
     */
    function cancelPending(bytes32 operation) external onlyAnyOwner {
        uint256 ownerIndex = ownersIndices[msg.sender] - 1;
        require((votesMaskByOperation[operation] & (2 ** ownerIndex)) != 0, "cancelPending: operation not found for this user");

        votesMaskByOperation[operation] &= ~(2 ** ownerIndex);
        uint256 operationVotesCount = votesCountByOperation[operation] - 1;
        votesCountByOperation[operation] = operationVotesCount;

        emit OperationDownvoted(operation, operationVotesCount, _owners.length, msg.sender);

        if (operationVotesCount == 0) {
            deleteOperation(operation);
            emit OperationCancelled(operation, msg.sender);
        }
    }

    /**
     * @dev Allows owners to change ownership
     * @param newOwners defines array of addresses of new owners
     */
    function transferOwnership(address[] calldata newOwners) external {
        transferOwnershipWithHowMany(newOwners, newOwners.length);
    }

    /**
     * @dev Allows owners to change ownership
     * @param newOwners defines array of addresses of new owners
     * @param newHowManyOwnersDecide defines how many owners can decide
     */
    function transferOwnershipWithHowMany(address[] memory newOwners, uint256 newHowManyOwnersDecide) public onlyManyOwners {
        require(newOwners.length > 0, "transferOwnershipWithHowMany: owners array is empty");
        require(newOwners.length <= 256, "transferOwnershipWithHowMany: owners count is greater then 256");
        require(newHowManyOwnersDecide > 0, "transferOwnershipWithHowMany: newHowManyOwnersDecide equal to 0");
        require(newHowManyOwnersDecide <= newOwners.length, "transferOwnershipWithHowMany: newHowManyOwnersDecide exceeds the number of owners");

        // Reset owners reverse lookup table
        for (uint256 j = 0; j < _owners.length; j++) {
            delete ownersIndices[_owners[j]];
        }

        for (uint256 i = 0; i < newOwners.length; i++) {
            require(newOwners[i] != address(0), "transferOwnershipWithHowMany: owners array contains zero");
            require(ownersIndices[newOwners[i]] == 0, "transferOwnershipWithHowMany: owners array contains duplicates");
            ownersIndices[newOwners[i]] = i + 1;
        }
        
        emit OwnershipTransferred(_owners, _howManyOwnersDecide, newOwners, newHowManyOwnersDecide);

        _owners = newOwners;
        _howManyOwnersDecide = newHowManyOwnersDecide;
        _allOperations.length = 0;
        _ownersGeneration++;
    }

    // GETTERS

    function getOwnersGeneration() external view returns (uint256) {
        return _ownersGeneration;
    }
    
    function getHowManyOwnersDecide() external view returns (uint256) {
        return _howManyOwnersDecide;
    }

    function getInsideCallSender() external view returns (address) {
        return _insideCallSender;
    }

    function getInsideCallCount() external view returns (uint256) {
        return _insideCallCount;
    }

    function getOwners() external view returns(address [] memory) {
        return _owners;
    }

    function getAllOperations() external view returns (bytes32 [] memory) {
        return _allOperations;
    }
}

/**
 * @title MinterRole
 * @dev Library for managing mint actions.
 */
contract MinterRole is Multiownable {
    using Roles for Roles.Role;

    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    Roles.Role private _minters;

    modifier onlyMinter() {
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) external onlyManyOwners {
        _addMinter(account);
    }

    function renounceMinter(address account) external onlyManyOwners {
        _removeMinter(account);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(account);
    }
}

/**
 * @title PauserRole
 * @dev Library for managing pause/unpause actions.
 */
contract PauserRole is Multiownable {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    modifier onlyPauser() {
        require(isPauser(msg.sender), "PauserRole: caller does not have the Pauser role");
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) external onlyManyOwners {
        _addPauser(account);
    }

    function renouncePauser(address account) external onlyManyOwners {
        _removePauser(account);
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}

/**
 * @title FreezerRole
 * @dev Library for managing freezing/unfreezing actions.
 */
contract FreezerRole is Multiownable {
    using Roles for Roles.Role;

    event FreezerAdded(address indexed account);
    event FreezerRemoved(address indexed account);

    Roles.Role private _freezers;

    modifier onlyFreezer() {
        require(isFreezer(msg.sender), "FreezerRole: caller does not have the Freezer role");
        _;
    }

    function isFreezer(address account) public view returns (bool) {
        return _freezers.has(account);
    }

    function addFreezer(address account) external onlyManyOwners {
        _addFreezer(account);
    }

    function renounceFreezer(address account) external onlyManyOwners {
        _removeFreezer(account);
    }

    function _addFreezer(address account) internal {
        _freezers.add(account);
        emit FreezerAdded(account);
    }

    function _removeFreezer(address account) internal {
        _freezers.remove(account);
        emit FreezerRemoved(account);
    }
}

/**
 * @dev Implementation of the `IERC20` interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 * For a generic mechanism see `ERC20Mintable`.
 *
 * *For a detailed writeup see our guide [How to implement supply
 * mechanisms](https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226).*
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an `Approval` event is emitted on calls to `transferFrom`.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn&#39;t required by the specification.
 *
 * Finally, the non-standard `decreaseAllowance` and `increaseAllowance`
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See `IERC20.approve`.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    /**
     * @dev See `IERC20.totalSupply`.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See `IERC20.balanceOf`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See `IERC20.allowance`.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See `IERC20.transferFrom`.
     *
     * Emits an `Approval` event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of `ERC20`;
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `value`.
     * - the caller must have allowance for `sender`&#39;s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to `approve` that can be used as a mitigation for
     * problems described in `IERC20.approve`.
     *
     * Emits an `Approval` event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to `transfer`, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a `Transfer` event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destoys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a `Transfer` event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an `Approval` event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller&#39;s allowance.
     *
     * See `_burn` and `_approve`.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }
}

/**
 * @dev Extension of `ERC20` that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract ERC20Burnable is ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See `ERC20._burn`.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev See `ERC20._burnFrom`.
     */
    function burnFrom(address account, uint256 amount) external {
        _burnFrom(account, amount);
    }
}

/**
 * @dev Extension of `ERC20` that adds a set of accounts with the `MinterRole`,
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20, MinterRole {
    /**
     * @dev See `ERC20._mint`.
     *
     * Requirements:
     *
     * - the caller must have the `MinterRole`.
     */
    function mint(address account, uint256 amount) external onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }
}

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
contract Pausable is PauserRole {
    /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state. Assigns the Pauser role
     * to the deployer.
     */
    constructor () internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() external onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() external onlyPauser whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

/**
 * @title Pausable token
 * @dev ERC20 with pausable transfers and allowances.
 *
 * Useful if you want to e.g. stop trades until the end of a crowdsale, or have
 * an emergency switch for freezing all token transfers in the event of a large
 * bug.
 */
contract ERC20Pausable is ERC20, Pausable {
    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}

/**
 * @dev Contract module which allows to owner of contract
 * freeze/unfreeze specific account, for prevent some emergency situations
 */
contract Freezable is FreezerRole {
    /**
     * @dev The mapping addresses of frozen accounts
     */ 
    mapping (address => bool) private _frozenAccounts;

    /**
     * @dev Emitted when the some account has been freezed.
     */
    event Freezed(address account);

    /**
     * @dev Emitted when the some account has been unfreezed.
     */
    event Unfreezed(address account);

    /**
     * @dev returns bool if account is frozen or not
     */
    function frozen(address account) public view returns (bool) {
        return _frozenAccounts[account];
    }

    /**
     * @dev Works only if account not frozen
     */
    modifier whenNotFrozen(address account) {
        require(_frozenAccounts[account] == false, "whenNotFrozen: already frozen");
        _;
    }

    /**
     * @dev Works only if account frozen
     */
    modifier whenFrozen(address account) {
        require(_frozenAccounts[account] == true, "whenFrozen: not frozen");
        _;
    }

    /**
     * @dev Freeze this account
     */
    function freeze(address account) external onlyFreezer whenNotFrozen(account) {
        _frozenAccounts[account] = true;
        emit Freezed(account);
    }

    /**
     * @dev Unfreeze this account
     */
    function unFreeze(address account) external onlyFreezer whenFrozen(account) {
        _frozenAccounts[account] = false;
        emit Unfreezed(account);
    }
}

/**
 * @title Freezable token
 * @dev ERC20 with freezable transfers and allowances.
 */
contract ERC20Freezable is ERC20, Freezable {
    function transfer(address to, uint256 value) public whenNotFrozen(msg.sender) whenNotFrozen(to) returns (bool) {
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public whenNotFrozen(msg.sender) whenNotFrozen(to) returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function approve(address spender, uint256 value) public whenNotFrozen(msg.sender) returns (bool) {
        return super.approve(spender, value);
    }

    function increaseAllowance(address spender, uint256 addedValue) public whenNotFrozen(msg.sender) returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotFrozen(msg.sender) returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}

/**
 * @dev USD Dao Coin includes main information about token
 */
contract USDDaocoin is ERC20Burnable, ERC20Mintable, ERC20Pausable, ERC20Freezable {
    string private _name = "USD Daocoin";
    string private _symbol = "USDD";
    uint8 private _decimals = 18;
    string private _version = "1.0.0";

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * > Note that this information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * `IERC20.balanceOf` and `IERC20.transfer`.
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the version of the token.
     */
    function version() external view returns (string memory) {
        return _version;
    }
}