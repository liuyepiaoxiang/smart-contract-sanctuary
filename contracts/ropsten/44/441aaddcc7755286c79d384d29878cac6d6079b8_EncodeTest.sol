/**
 *Submitted for verification at Etherscan.io on 2019-07-09
*/

// Generated by Jthereum TEST version!
pragma solidity ^0.5.2;
contract EncodeTest
{
	function test1(bytes1[] memory id) public 
	{
		bytes memory b = encode(id);
		emit Result(b.length, b);
	}
	event Result(uint256 result, bytes b);

	function encode(bytes1[] memory id) public pure returns (bytes memory) 
	{
		return abi.encodePacked(id);
	}
	function returnIt(bytes memory a) public pure returns (bytes memory) 
	{
		return a;
	}

}