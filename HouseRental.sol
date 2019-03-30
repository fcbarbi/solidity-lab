// HouseRental.sol 
// adapted fcbarbi from Theodosis Mourouzis and Jayant Tandon's code 
// March 2019 

pragma solidity ^0.5.0; 

import "https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol"
// import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
// https://docs.oraclize.it/

contract HouseRental is usingOraclize{
	//Initiate the contract and inherit from the Oracle service Oraclize
	struct RentsPaid {
	uint month;
	uint amount;
}
enum Status {Created, Active, Terminated}

uint daysInMonth;
Status public status;
address payable public landlord;
address payable public tenant;

string public house; //Identifies the house that is to be rented, can be done using the address of the house

RentsPaid[] public rentsPaid; //array of uint to store the rents that are paid

uint public timeCreated; //indicates the time on the block that the contract has been deployed

uint public termLength; //The number of months for which the house will be on rent

uint public rent = 1 ether; //Declares the rent that is to be paid, "1 ether" is just an example

uint public securityDeposit = 1 ether;
uint public lateFee;
bool termsBreached;

modifier onlyTenant() {
	assert(msg.sender == tenant);
	_;
}

modifier onlyLandlord() {
	assert(msg.sender == landlord);
	_;
}

modifier policyBreached() {
	assert(!termsBreached);
	_;
}

event rentPaid();
event contractActive();
event contractTerminated();
event termBreached();
event LogNewOraclizeQuery(string description);

/* Getter functions */

function getStatus() view public returns(Status) {
	return status;
}

function getLandlord() view public returns(address) {
	return landlord;
}

function getTenant() view public returns(address) {
	return tenant;
}

function getHouse() view public returns(string memory) {
	return house;
}

function getTimeCreated() view public returns(uint) {
	return timeCreated;
}

function getTermLength() view public returns(uint) {
	return termLength;
}

function getRent() view public returns(uint) {
	return rent;
}

function getSecurityDeposit() view public returns(uint) {
	return securityDeposit;
}

/* Cannot implement this function at the moment as it is unsupported:
function getRentsPaid() view public returns(RentsPaid[] memory) {
	return rentsPaid;
}
*/

constructor (uint _rent, string memory _house, uint _termLength) public {
	landlord = msg.sender; // landlord's address, thus it should be the landlord who first deploys the contract
	rent = _rent;
	house = _house;
	termLength = _termLength;
	timeCreated = block.timestamp;
	termsBreached = false;
}

function beginLease() public payable policyBreached {
	require(msg.sender != landlord && status == Status.Created && msg.value == securityDeposit);
	tenant = msg.sender;
	landlord.transfer(msg.value);
	status = Status.Active;
	emit contractActive();
}

function CheckTerms() public payable returns(bytes32){
	if(oraclize_getPrice("URL") > address(this).balance) {
		emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
	} else {
		emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
		return oraclize_query(60*3600, "URL", "INSERT TERMS HERE, please respond in the format: true / false");
	}
}

function __callback(bytes32 myid, bool result) public {
	if (msg.sender != oraclize_cbAddress()) revert();
	if(CheckTerms() == "true"){
		result = true;
	} else {
		result = false;
	}
	termsBreached = result;
}

function payRent() public payable onlyTenant {
	require(status == Status.Active);
	require(msg.value == rent + lateFee);
	landlord.transfer(msg.value);
	rentsPaid.push(RentsPaid({
		month : rentsPaid.length + 1,
		amount : msg.value
	}));
}

function TerminateContract() public payable onlyLandlord {
	if(!termsBreached) {
		tenant.transfer(securityDeposit);
	}
	emit contractTerminated();
	selfdestruct(landlord);
}

function tokenFallback() public {
	landlord.transfer(address(this).balance);
}

function () external {
	tokenFallback();
}

}

