/**
 *Submitted for verification at Etherscan.io on 2019-07-09
*/

pragma solidity ^0.4.26;
contract AdminInterface {

    function addCandidate(
        address _candidateAddr, 
        address _rewardAddr,
        bytes32 _name
    ) public;

    function deleteCandidate(
        address _candidateAddr
    ) public;

    function setCapacity(
        uint _capacity
    ) public;

    function calVoteResult() public;
}
contract VoteInterface {

    /**
     * 投票  
     */
    function vote(
        address voterAddr, 
        address candidateAddr, 
        uint num
    ) public ;

    /**
     * 用于批量投票  For non locked voting
     */
    function batchVote(
        address voterAddr, 
        address[] candidateAddrs, 
        uint[] nums
    ) public;

    function setRewardAddr(
        address _candidateAddr, 
        address _rewardAddr
    ) public;

    function updateCandidateAddr(
        address _oldCandidateAddr, 
        address _newCandidateAddr
    ) public;

    /**
     * 撤回对某个候选人的投票 Withdraw a vote on a candidate.
     */
    function cancelVoteForCandidate(
        address voterAddr, 
        address candidateAddr, 
        uint num
    ) public ;

    function refreshVoteForAll() public;

}
contract FetchVoteInterface {
     /**
     * 是否为竞选阶段
     */
	function isRunUpStage() public view returns (
	    bool
	);

    /**
     * 获取所有候选人的详细信息
     * Get detailed information about all candidates.
     */
    function fetchAllCandidates() public view returns (
        address[] addrs, 
        bytes32[] names
    );

    /**
     * 获取所有投票人的详细信息
     */
    function fetchAllVoters() public view returns (
        address[] voterAddrs, 
        uint[] voteNumbers
    );

    /**
     * 获取所有投票人的投票情况
     */
    function fetchVoteInfoForVoter(
        address voterAddr
    ) public view returns (
        address[] addrs, 
        uint[] nums
    );

    /**
     * 获取某个候选人的总得票数
     * Total number of votes obtained from candidates
     */
    function fetchVoteNumForCandidate(
        address candidateAddr
    ) public view returns (
        uint num
    );

    /**
     * 获取某个投票人已投票数
     * Total number of votes obtained from voterAddr
     */
    function fetchVoteNumForVoter(
        address voterAddr
    ) public view returns (
        uint num
    );

    /**
     * 获取某个候选人被投票详细情况
     */
    function fetchVoteInfoForCandidate(
        address candidateAddr
    ) public view returns (
        address[] addrs, 
        uint[] nums
    );

    /**
     * 获取所有候选人的得票情况
     */
    function fetchAllVoteResult() public view returns (
        address[] candidateAddrs, 
        address[] rewardAddrs,
        uint[] nums
    );
}
contract HpbNodesInterface {

    function addStage() public;

    function transferOwnership(
        address newOwner
    ) public;

    function addHpbNode(
        address coinbase, 
        bytes32 cid1,
        bytes32 cid2,
        bytes32 hid
    ) public;

    function addHpbNodeBatch(
        address[] coinbases, 
        bytes32[] cid1s,
        bytes32[] cid2s,
        bytes32[] hids
    ) public;


    function getAllHpbNodes() public view returns (
        address[] coinbases, 
        bytes32[] cid1s,
        bytes32[] cid2s,
        bytes32[] hids
    );
}
contract FechHpbBallotAddrInterface {

    function setContractAddr(
        address _contractAddr
    ) public;

    /**
     * 得到最获取智能合约地址
     */
    function getContractAddr() public view returns(
        address _contractAddr
    );

    function setFunStr(
        string _funStr
    ) public;

    /**
     * 得到最获取智能合约调用方法
     */
    function getFunStr() public view returns(
        string _funStr
    );
}
contract Ownable {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner);
        // Do not forget the "_;"! It will be replaced by the actual function
        // body when the modifier is used.
        _;
    }

    function transferOwnership(
        address newOwner
    ) onlyOwner public {
        owner = newOwner;
    }

    function getOwner() public view returns (
        address
    ) {
        return owner;
    }
    // 合约管理员，可以添加和删除候选人
    mapping (address => address) public adminMap;

    modifier onlyAdmin {
        require(adminMap[msg.sender] != 0);
        _;
    }

    function addAdmin(
        address addr
    ) onlyOwner public {
        require(adminMap[addr] == 0);
        adminMap[addr] = addr;
    }

    function deleteAdmin(
        address addr
    ) onlyOwner public {
        require(adminMap[addr] != 0);
        adminMap[addr] = 0;
    }

}
library SafeMath {

    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting &#39;a&#39; not being zero, but the
        // benefit is lost if &#39;b&#39; is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(
        uint256 a, 
        uint256 b
    ) internal pure returns (
        uint256
    ) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(
        uint256 a, 
        uint256 b
    ) internal pure returns (
        uint256
    ) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(
        uint256 a, 
        uint256 b
    ) internal pure returns (
        uint256 c
    ) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}
contract HpbBallotTool is Ownable {
    using SafeMath for uint256;
    address public hpbNodeAddress;
    address public fechHpbBallotAddrAddress;
    address[] public hpbBallots;
    mapping (address => uint) hpbBallotIndex;
    address public ballotAddressForNodes;
    event ReceivedHpb(
        address indexed sender, 
        uint amount
    );
    event RewardVoteResultForCandidate(
        address indexed from,
        address indexed to,
        uint indexed value
    );

    // 接受HPB转账
    function () payable external {
        emit ReceivedHpb(
            msg.sender, 
            msg.value
        );
    }

    // 销毁合约，并把合约余额返回给合约拥有者
    function kill() onlyOwner public {
        selfdestruct(owner);
    }

    function withdraw(
        uint _value
    ) onlyOwner payable public {
        require(address(this).balance >= _value);
        owner.transfer(_value);
    }

    constructor () payable public {
        owner = msg.sender;
        adminMap[msg.sender] = msg.sender;
        hpbBallots.push(0);
        hpbNodes.push(HpbNode(msg.sender, 0, 0, 0));
        candidateArray.push(Candidate(msg.sender,msg.sender, 0));
    }

    function setHpbNodeAddress(
        address _hpbNodeAddress
    ) onlyAdmin public {
        hpbNodeAddress = _hpbNodeAddress;
    }

    function setFechHpbBallotAddrAddresss(
        address _fechHpbBallotAddrAddress
    ) onlyAdmin public {
        fechHpbBallotAddrAddress = _fechHpbBallotAddrAddress;
    }

    function addHpbBallotAddress(
        address _hpbBallotAddress
    ) onlyAdmin public {
        require(hpbBallotIndex[_hpbBallotAddress] == 0);
        uint index=hpbBallots.push(_hpbBallotAddress) - 1;
        hpbBallotIndex[_hpbBallotAddress] = index;
    }

    function updateHpbBallotAddress(
        address _hpbBallotAddress, 
        address _newHpbBallotAddress
    ) onlyAdmin public {
        uint index=hpbBallotIndex[_hpbBallotAddress];
        require(index != 0);
        hpbBallots[index] = _newHpbBallotAddress;
        hpbBallotIndex[_hpbBallotAddress] = 0;
        hpbBallotIndex[_newHpbBallotAddress] = index;
    }

    function _getAdminInterface(
        uint _index
    ) internal view returns  (
        AdminInterface adminInterface
    ) {
        require(_index != 0);
        return AdminInterface(hpbBallots[_index]);
    }

    function _getVoteInterface(
        uint _index
    ) internal view returns (
        VoteInterface voteInterface
    ) {
        require(_index != 0);
        return VoteInterface(hpbBallots[_index]);
    }

    function _getFetchVoteInterface(
        uint _index
    ) internal view returns  (
        FetchVoteInterface fetchVoteInterface
    ) {
        require(_index != 0);
        return FetchVoteInterface(hpbBallots[_index]);
    }

    function _getHpbNodesInterface() internal view returns  (
        HpbNodesInterface hpbNodesInterface
    ) {
        require(hpbNodeAddress != 0);
        return HpbNodesInterface(hpbNodeAddress);
    }

    function _getFechHpbBallotAddrInterface() internal view returns (
        FechHpbBallotAddrInterface fechHpbBallotAddrInterface
    ) {
        require(fechHpbBallotAddrAddress != 0);
        return FechHpbBallotAddrInterface(fechHpbBallotAddrAddress);
    }


    function addCandidate(
        address _candidateAddr, 
        address _rewardAddr, 
        bytes32 _name
    ) public {
        addCandidateByIndex(hpbBallots.length - 1, _candidateAddr, _rewardAddr, _name);
    }

    function addCandidateByIndex(
        uint index, 
        address _candidateAddr, 
        address _rewardAddr,
        bytes32 _name
    ) public {
        _getAdminInterface(index).addCandidate(_candidateAddr, _rewardAddr, _name);
    }

    function batchAddCandidate(
        address[] _candidateAddrs, 
        address[] _rewardAddrs, 
        bytes32[] _names
    ) public {
        batchAddCandidateByIndex(hpbBallots.length - 1, _candidateAddrs, _rewardAddrs, _names);
    }

    function batchAddCandidateByIndex(
        uint index, 
        address[] _candidateAddrs,
        address[] _rewardAddrs, 
        bytes32[] _names
    ) public {
        for (uint i=0;i < _candidateAddrs.length;i++) {
            addCandidateByIndex(index, _candidateAddrs[i], _rewardAddrs[i], _names[i]);
        }
    }

    /**
     * 根据阶段删除候选者
     * @param _candidateAddr 候选者账户地址 Candidate account address
     */
    function deleteCandidate(
        address _candidateAddr
    ) public {
        deleteCandidateByIndex(hpbBallots.length - 1, _candidateAddr);
    }

    function deleteCandidateByIndex(
        uint index, 
        address _candidateAddr
    ) public {
        _getAdminInterface(index).deleteCandidate(_candidateAddr);
    }

    function batchDeleteCandidate(
        address[] _candidateAddrs
    ) public {
        batchDeleteCandidateByIndex(hpbBallots.length - 1, _candidateAddrs);
    }

    function batchDeleteCandidateByIndex(
        uint index, 
        address[] _candidateAddrs
    ) public {
        for (uint i=0;i < _candidateAddrs.length;i++) {
            deleteCandidateByIndex(index,_candidateAddrs[i]);
        }
    }

    function updateCandidateAddr(
        address _oldCandidateAddr, 
        address _newCandidateAddr
    ) public {
        updateCandidateAddrByIndex(hpbBallots.length - 1, _oldCandidateAddr, _newCandidateAddr);
    }

    function updateCandidateAddrByIndex(
        uint index, 
        address _oldCandidateAddr, 
        address _newCandidateAddr
    ) public {
        _getVoteInterface(index).updateCandidateAddr(_oldCandidateAddr, _newCandidateAddr);
    }

    function batchUpdateCandidateAddr(
        address[] _oldCandidateAddrs, 
        address[] _newCandidateAddrs
    ) public {
        batchUpdateCandidateAddrByIndex(hpbBallots.length - 1, _oldCandidateAddrs, _newCandidateAddrs);
    }

    function batchUpdateCandidateAddrByIndex(
        uint index, 
        address[] _oldCandidateAddrs, 
        address[] _newCandidateAddrs
    ) public {
        for (uint i=0;i < _oldCandidateAddrs.length;i++) {
            updateCandidateAddrByIndex(index, _oldCandidateAddrs[i], _newCandidateAddrs[i]);
        }
    }

    function updateRewardAddr(
        address _candidateAddr, 
        address _rewardAddr
    ) public {
        updateCandidateAddrByIndex(hpbBallots.length - 1, _candidateAddr, _rewardAddr);
    }

    function updateRewardAddrByIndex(
        uint index, 
        address _candidateAddr, 
        address _rewardAddr
    ) public {
        _getVoteInterface(index).setRewardAddr(_candidateAddr, _rewardAddr);
    }

    function batchUpdateRewardAddr(
        address[] _candidateAddrs, 
        address[] _rewardAddrs
    ) public {
        batchUpdateCandidateAddrByIndex(hpbBallots.length - 1, _candidateAddrs, _rewardAddrs);
    }

    function batchUpdateRewardAddrByIndex(
        uint index, 
        address[] _candidateAddrs, 
        address[] _rewardAddrs
    ) public {
        for (uint i=0;i < _candidateAddrs.length;i++) {
            updateRewardAddrByIndex(index, _candidateAddrs[i], _rewardAddrs[i]);
        }
    }

    function setCapacity(
        uint _capacity
    ) public {
        setCapacityByIndex(hpbBallots.length - 1, _capacity);
    }

    function setCapacityByIndex(
        uint index, 
        uint _capacity
    ) public {
        _getAdminInterface(index).setCapacity(_capacity);
    }

    function calVoteResult() public {
        calVoteResultByIndex(hpbBallots.length - 1);
    }

    function calVoteResultByIndex(
        uint index
    ) public {
        _getAdminInterface(index).calVoteResult();
    }

    /**
     * 投票  
     */
    function  vote(
        address candidateAddr, 
        uint num
    ) public {
        voteByIndex(hpbBallots.length - 1, candidateAddr, num) ;
    }

    function  voteByIndex(
        uint index, 
        address candidateAddr, 
        uint num
    ) public {
        _getVoteInterface(index).vote(msg.sender, candidateAddr, num);
    }

    /**
     * 用于批量投票  For non locked voting
     */
    function  batchVote(
        address[] candidateAddrs, 
        uint[] nums
    ) public {
        batchVoteByIndex(hpbBallots.length - 1, candidateAddrs, nums);
    }

    function  batchVoteByIndex(
        uint index, 
        address[] candidateAddrs, 
        uint[] nums
    ) public {
        _getVoteInterface(index).batchVote(msg.sender, candidateAddrs, nums);
    }

    function refreshVoteForAll() public {
        refreshVoteForAllByIndex(hpbBallots.length - 1);
    }

    function refreshVoteForAllByIndex(
        uint index
    ) public {
        _getVoteInterface(index).refreshVoteForAll();
    }

    /**
     * 撤回对某个候选人的投票 Withdraw a vote on a candidate.
     */
    function cancelVoteForCandidate(
        address candidateAddr, 
        uint num
    ) public {
        cancelVoteForCandidateByIndex(hpbBallots.length - 1, candidateAddr, num);
    }

    function cancelVoteForCandidateByIndex(
        uint index, 
        address candidateAddr, 
        uint num
    ) public {
        _getVoteInterface(index).cancelVoteForCandidate(msg.sender, candidateAddr, num);
    }

    function  batchCancelVoteForCandidate(
        address[] candidateAddrs, 
        uint[] nums
    ) public {
        batchCancelVoteForCandidateByIndex(hpbBallots.length - 1, candidateAddrs, nums);
    }

    function  batchCancelVoteForCandidateByIndex(
        uint index, 
        address[] candidateAddrs, 
        uint[] nums
    ) public {
        for (uint i=0;i < candidateAddrs.length;i++) {
            _getVoteInterface(index).cancelVoteForCandidate(msg.sender, candidateAddrs[i], nums[i]);
        }
    }

    /**
     * 获取所有候选人的详细信息
     * Get detailed information about all candidates.
     */
    function fetchAllCandidates() public view returns (
        address[] addrs, 
        bytes32[] names
    ) {
        return fetchAllCandidatesByIndex(hpbBallots.length - 1);
    }

    function fetchAllCandidatesByIndex(
        uint index
    ) public view returns (
        address[] addrs, 
        bytes32[] names
    ) {
        return _getFetchVoteInterface(index).fetchAllCandidates();
    }

    /**
     * 获取所有投票人的详细信息
     */
    function fetchAllVoters() public view returns (
        address[] voterAddrs, 
        uint[] voteNumbers
    ) {
        return fetchAllVotersByIndex(hpbBallots.length - 1);
    }

    function fetchAllVotersByIndex(
        uint index
    ) public view returns (
        address[] voterAddrs, 
        uint[] voteNumbers
    ) {
        return _getFetchVoteInterface(index).fetchAllVoters();
    }

    /**
     * 获取所有投票人的投票情况
     */
    function fetchVoteInfoForVoter(
        address voterAddr
    ) public view returns (
        address[] addrs, 
        uint[] nums
    ) {
        return fetchVoteInfoForVoterByIndex(hpbBallots.length - 1, voterAddr);
    }

    function fetchVoteInfoForVoterByIndex(
        uint index, 
        address voterAddr
    ) public view returns (
        address[] addrs, 
        uint[] nums
    ) {
        return _getFetchVoteInterface(index).fetchVoteInfoForVoter(voterAddr);
    }

    /**
     * 获取某个候选人的总得票数
     * Total number of votes obtained from candidates
     */
    function fetchVoteNumForCandidate(
        address candidateAddr
    ) public view returns (uint num) {
        return fetchVoteNumForCandidateByIndex(hpbBallots.length - 1, candidateAddr);
    }

    function fetchVoteNumForCandidateByIndex(
        uint index, 
        address candidateAddr
    ) public view returns (uint num) {
        return _getFetchVoteInterface(index).fetchVoteNumForCandidate(candidateAddr);
    }

    /**
     * 获取某个投票人已投票数
     * Total number of votes obtained from voterAddr
     */
    function fetchVoteNumForVoter(
        address voterAddr
    ) public view returns (uint num) {
        return fetchVoteNumForVoterByIndex(hpbBallots.length - 1, voterAddr);
    }

    function fetchVoteNumForVoterByIndex(
        uint index, 
        address voterAddr
    ) public view returns (uint num) {
        return _getFetchVoteInterface(index).fetchVoteNumForVoter(voterAddr);
    }

    /**
     * 获取某个候选人被投票详细情况
     */
    function fetchVoteInfoForCandidate(
        address candidateAddr
    ) public view returns (
        address[] addrs, 
        uint[] nums
    ) {
        return fetchVoteInfoForCandidateByIndex(hpbBallots.length - 1, candidateAddr);
    }

    function fetchVoteInfoForCandidateByIndex(
        uint index, 
        address candidateAddr
    ) public view returns (
        address[] addrs, 
        uint[] nums
    ) {
        return _getFetchVoteInterface(index).fetchVoteInfoForCandidate(candidateAddr);
    }

    function fetchAllVoteResultByIndex(
        uint index
    ) public view returns (
        address[] candidateAddrs, 
        address[] rewardAddrs,
        uint[] nums
    ) {
        return _getFetchVoteInterface(index).fetchAllVoteResult();
    }

    function fetchAllVoteResult() public view returns (
        address[] candidateAddrs, 
        address[] rewardAddrs,
        uint[] nums
    ) {
        return fetchAllVoteResultByIndex(hpbBallots.length - 1);
    }

    /**
     * 获取所有候选人的得票情况
     */
    function fetchAllResult() public view returns (
        address[] candidateAddrs, 
        address[] rewardAddrs,
        uint[] nums
    ) {
        return fetchAllResultByIndex(hpbBallots.length - 1);
    }

    function fetchAllResultByIndex(
        uint index
    ) public view returns (
        address[] candidateAddrs, 
        address[] rewardAddrs,
        uint[] nums
    ) {
        return _getFetchVoteInterface(index).fetchAllVoteResult();
    }

    /**
     * 返回给节点的投票数据
     */
    function fetchAllVoteResultForNodes(
        uint _block
    ) public view returns (
        uint fromBlock, 
        uint toBlock,
        address[] addrs,
        uint[] nums
    ) {
        if (FetchVoteInterface(ballotAddressForNodes).isRunUpStage()) {
            return (0, 0,new address[](0),new uint[](0));
        }
        address[] memory _candidateAddrs;
        address[] memory _rewardAddrs;
        uint[] memory _nums;
        (_candidateAddrs,_rewardAddrs,_nums) = FetchVoteInterface(ballotAddressForNodes).fetchAllVoteResult();
        if (_nums.length < 1) {
            return (0, 0,new address[](0),new uint[](0));
        } else {
            return (_block.sub(200), _block,_candidateAddrs,_nums);
        }
    }

    function fetchResultForNodes() public view returns (
        address[] candidateAddrs, 
        address[] rewardAddrs,
        uint[] nums
    ) {
        if (FetchVoteInterface(ballotAddressForNodes).isRunUpStage()) {
            return (new address[](0), new address[](0),new uint[](0));
        }
        address[] memory _candidateAddrs;
        address[] memory _rewardAddrs;
        uint[] memory _nums;
        (_candidateAddrs,_rewardAddrs,_nums) = FetchVoteInterface(ballotAddressForNodes).fetchAllVoteResult();
        if (_nums.length < 1) {
            return (new address[](0), new address[](0),new uint[](0));
        } else {
            return (_candidateAddrs, _rewardAddrs,_nums);
        }
    }

    // 候选者按比例发送HPB奖励给投票者,比如rate为投票1000就奖励1个HPB
    function rewardVoteResultForCandidate(
        address candidateAddr, 
        uint rate
    ) payable public {
        require(msg.value >= 0, "金额不能为0");
        require(msg.sender == candidateAddr, "必须是候选者自己");
        uint num=fetchVoteNumForCandidate(candidateAddr);
        require(num > 1 finney);
        require(rate >= 100); // 最多奖励百分之一
        address[] memory _addrs;
        uint[] memory _nums;
        uint reward=0;
        (_addrs,_nums) = fetchVoteInfoForCandidate(candidateAddr);
        for (uint i = 0;i < _addrs.length;i++) {
            if (_addrs[i] != 0) {
                uint _value=_nums[i].div(rate);
                _addrs[i].transfer(_value);
                reward = reward.add(_value);
                emit RewardVoteResultForCandidate(msg.sender, _addrs[i],_value);
            }
        }
        require(msg.value >= reward, "发送的金额不足");
    }

    function addHpbNode(
        address coinbase, 
        bytes32 cid1,
        bytes32 cid2,
        bytes32 hid
    ) public {
        _getHpbNodesInterface().addHpbNode(coinbase, cid1, cid2, hid);
    }

    function addHpbNodeBatch(
        address[] coinbases, 
        bytes32[] cid1s,
        bytes32[] cid2s,
        bytes32[] hids
    ) public {
        _getHpbNodesInterface().addHpbNodeBatch(coinbases, cid1s, cid2s, hids);
    }

    function getAllHpbNodes() public view returns (
        address[] coinbases, 
        bytes32[] cid1s,
        bytes32[] cid2s,
        bytes32[] hids
    ) {
        return _getHpbNodesInterface().getAllHpbNodes();
    }


    /**
     * 得到最获取智能合约地址
     */
    function getContractAddr() public view returns(
        address _contractAddr
    ) {
        return _getFechHpbBallotAddrInterface().getContractAddr();
    }

    /**
     * 得到最获取智能合约调用方法
     */
    function getFunStr() public view returns(
        string _funStr
    ) {
        return _getFechHpbBallotAddrInterface().getFunStr();
    }

    function transferNodeContractOwnership(
        address newOwner
    ) onlyOwner public {
        _getHpbNodesInterface().transferOwnership(newOwner);
    }

    struct Candidate {
        address candidateAddr;
        address rewardAddr;
        bytes32 name;
    }
    Candidate[] candidateArray;
    mapping (address => uint) candidateIndexMap;

    function addCandidateCache(
        address[] _candidateAddrs, 
        address[] _rewardAddrs, 
        bytes32[] _names
    ) onlyAdmin public {
        require(_candidateAddrs.length == _names.length);
        for (uint i = 0;i < _candidateAddrs.length;i++) {
            uint index = candidateIndexMap[_candidateAddrs[i]];
            // 必须地址还未使用
            require(index == 0);
            candidateIndexMap[_candidateAddrs[i]] = candidateArray.push(
                Candidate(
                    _candidateAddrs[i],
                    _rewardAddrs[i],
                    _names[i]
                )
            )-1;
        }
    }

    function deleteCandidateCache(
        address _candidateAddr
    ) onlyAdmin public {
        uint index = candidateIndexMap[_candidateAddr];
        // 必须地址存在
        require(index != 0);
        for (uint i = index;i < candidateArray.length - 1;i++) {
            candidateArray[i] = candidateArray[i+1];
            candidateIndexMap[candidateArray[i].candidateAddr] = i;
        }
        delete candidateArray[candidateArray.length - 1];
        candidateArray.length--;
        candidateIndexMap[_candidateAddr] = 0;
    }

    function batchDeleteCandidateCache(
        address[] _candidateAddrs
    ) onlyAdmin public {
        for (uint i = 0;i < _candidateAddrs.length;i++) {
            deleteCandidateCache(_candidateAddrs[i]);
        }
    }

    function clearCandidateCache() onlyAdmin public {
        require(candidateArray.length > 1);
        uint cl=candidateArray.length - 1;
        address[] memory _addrs=new address[](cl);
        for (uint i=1;i <= cl;i++) {
            _addrs[i-1] = candidateArray[i].candidateAddr;
        }
        for (uint j = 1;j < _addrs.length;j++) {
            deleteCandidateCache(_addrs[i]);
        }
    }

    function addAllCandidates() onlyAdmin public {
        require(candidateArray.length > 1);
        uint cl=candidateArray.length - 1;
        address[] memory _candidateAddrs=new address[](cl);
        address[] memory _rewardAddrs=new address[](cl);
        bytes32[] memory _names=new bytes32[](cl);
        for (uint i=1;i <= cl;i++) {
            _candidateAddrs[i-1] = candidateArray[i].candidateAddr;
            _rewardAddrs[i-1] = candidateArray[i].rewardAddr;
            _names[i-1] = candidateArray[i].name;
        }
        batchAddCandidate(_candidateAddrs,_rewardAddrs, _names);
    }

    struct HpbNode {
        address coinbase;
        bytes32 cid1;
        bytes32 cid2;
        bytes32 hid;
    }
    HpbNode[] hpbNodes;
    mapping (address => uint) hpbNodesIndexMap;

    function addNodesCache(
        address[] coinbases, 
        bytes32[] cid1s,
        bytes32[] cid2s,
        bytes32[] hids
    ) onlyAdmin public {
        require(coinbases.length == cid1s.length);
        require(coinbases.length == cid2s.length);
        require(coinbases.length == hids.length);
        for (uint i = 0;i < coinbases.length;i++) {
            uint index = hpbNodesIndexMap[coinbases[i]];
            // 必须地址还未使用
            require(index == 0);
            hpbNodesIndexMap[coinbases[i]] = hpbNodes.push(HpbNode(coinbases[i],cid1s[i],cid2s[i],hids[i]))-1;
        }
    }

    function deleteHpbNodeCache(
        address coinbase
    ) onlyAdmin public {
        uint index = hpbNodesIndexMap[coinbase];
        // 必须地址存在
        require(index != 0);
        for (uint i = index;i < hpbNodes.length - 1;i++) {
            hpbNodes[i] = hpbNodes[i+1];
            hpbNodesIndexMap[hpbNodes[i].coinbase] = i;
        }
        delete hpbNodes[hpbNodes.length - 1];
        hpbNodes.length--;
        hpbNodesIndexMap[coinbase] = 0;
    }

    function batchDeleteHpbNodeCache(
        address[] coinbases
    ) onlyAdmin public {
        for (uint i = 0;i < coinbases.length;i++) {
            deleteHpbNodeCache(coinbases[i]);
        }
    }

    function clearHpbNodeCache() onlyAdmin public {
        require(hpbNodes.length > 1);
        uint cl=hpbNodes.length - 1;
        address[] memory _coinbases=new address[](cl);
        for (uint i = 1;i < hpbNodes.length;i++) {
            _coinbases[i-1] = hpbNodes[i].coinbase;
        }
        for (uint j = 0;j < _coinbases.length;j++) {
            deleteHpbNodeCache(_coinbases[j]);
        }
    }

    function getAllHpbNodesCache() public constant returns (
        address[] coinbases, 
        bytes32[] cid1s,
        bytes32[] cid2s,
        bytes32[] hids
    ) {
        require(hpbNodes.length > 1);
        uint cl=hpbNodes.length - 1;
        address[] memory _coinbases=new address[](cl);
        bytes32[] memory _cid1s=new bytes32[](cl);
        bytes32[] memory _cid2s=new bytes32[](cl);
        bytes32[] memory _hids=new bytes32[](cl);
        for (uint i = 1;i < hpbNodes.length;i++) {
            _coinbases[i-1] = hpbNodes[i].coinbase;
            _cid1s[i-1] = hpbNodes[i].cid1;
            _cid2s[i-1] = hpbNodes[i].cid2;
            _hids[i-1] = hpbNodes[i].hid;
        }
        return (_coinbases, _cid1s,_cid2s,_hids);
    }

    function switchNodes() onlyAdmin public {
        require(hpbNodes.length > 1);
        uint cl=hpbNodes.length - 1;
        address[] memory _coinbases=new address[](cl);
        bytes32[] memory _cid1s=new bytes32[](cl);
        bytes32[] memory _cid2s=new bytes32[](cl);
        bytes32[] memory _hids=new bytes32[](cl);
        for (uint i = 1;i < hpbNodes.length;i++) {
            _coinbases[i-1] = hpbNodes[i].coinbase;
            _cid1s[i-1] = hpbNodes[i].cid1;
            _cid2s[i-1] = hpbNodes[i].cid2;
            _hids[i-1] = hpbNodes[i].hid;
        }
        _getHpbNodesInterface().addStage();
        _getHpbNodesInterface().addHpbNodeBatch(_coinbases, _cid1s, _cid2s, _hids);
        _getFechHpbBallotAddrInterface().setContractAddr(address(this));
        ballotAddressForNodes = hpbBallots[hpbBallots.length-1];
        // 0x8b7261bd=bytes4(keccak256("fetchAllVoteResultForNodes(uint256)"))
        _getFechHpbBallotAddrInterface().setFunStr("0x8b7261bd");
    }
}