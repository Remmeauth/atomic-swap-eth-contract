pragma solidity ^0.4.21;

import '../contracts/ERC20Interface.sol';

contract RemmeTokenMock is ERC20Interface {

	mapping(address => uint256) balances;
	uint _totalSupply = 10000000000000;
	uint8 decimals = 4;

	function RemmeTokenMock(){
		//constructor
	}

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed from, address indexed spender, uint256 value);

	function totalSupply() constant returns(uint256 supply) {
		return _totalSupply;
	}

	function balanceOf(address _owner) constant returns(uint256 balance) {
		return balances[_owner];
	}

	function transfer(address _to, uint256 _value) returns(bool success) {
		require(_to != address(0));
		require(_value <= balances[msg.sender]);

		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
		emit Transfer(msg.sender, _to, _value);
		return true;
	}

	function transferFrom(address _from, address _to, uint256 _value) returns(bool success) {
		require(_to != address(0));
		require(_value <= balances[_from]);
		require(_value <= allowed[_from][msg.sender]);

		balances[_from] = balances[_from].sub(_value);
		balances[_to] = balances[_to].add(_value);
		allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
		emit Transfer(_from, _to, _value);
		return true;
	}
	function approve(address _spender, uint256 _value) returns(bool success) {
		allowed[msg.sender][_spender] = _value;
		emit Approval(msg.sender, _spender, _value);
		return true;
	}
	function allowance(address _owner, address _spender) constant returns(uint256 remaining) {
		return allowed[_owner][_spender];
	}

	// function symbol() constant returns(string);
	function decimals() constant returns(uint8) {
		return decimals;
	}
	// function name() constant returns(string);

}
