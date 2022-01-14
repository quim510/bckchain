// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Lottery
 * by Quim Bauxell for Blockchain/UPC
 * @dev lottery sc
 
 * The scope of this code is to first create a lottery scheme,
 * collect payments from each participant, 1 ETH for simplicity,
 * once the timer is over the prize can be sent to the winner.
 
 * This contract supports multiple lotteries one at a time.
 * ticketLedger keeps track of all participants in each lottery
 * iteration. resetLottery creates a new lottery.
 */
contract Lottery {

    // Owner of the game
    address owner;
    // The amount of wei raised so far
    uint256 balance;
    // Deadline in seconds (unix timestamp)
    uint256 deadline;
    // Bool to show if prize has been sent to the winner
    bool claimed; 
    // Number of tickets currently sold
    uint256 soldTickets;
    // first key -> current lottery identifier
    // second mapping -> id and adress for every bought ticket in this lottery shceme
    mapping (uint8 => mapping (uint256 => address)) ticketLedger;
    // identifier of the current lottery scheme
    uint8 lotteryNum;
    // Address of the winner of each lottery
    mapping (uint8 => address) winnerLedger;

    constructor (uint256 _seconds) {
        owner = msg.sender;
        balance = 0;
        deadline = block.timestamp + _seconds;
        claimed = false;
        soldTickets = 0;
        lotteryNum = 0;
    }

    //MODIFIERS

    // modifier to check if the function is called when tickets can still be purchased
    modifier inTime() {
        require(block.timestamp <= deadline, "Ticket purchasing period is over");
        _;
    }

    // modifier to check if the timer has reached its deadline
    modifier timerOver() {
        require(block.timestamp >= deadline, "Ticket purchasing period still ongoing");
        _;
    }

    // modifier to check if caller is owner
    modifier isOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    // modifier to check if the prize has already been collected
    modifier notClaimed () {
        require(claimed == false, "Prize has already been collected");
        _;
    }

    // modifier to check if the prize is yet to be collected
    modifier isClaimed () {
        require(claimed == true, "Lottery still ongoing");
        _;
    }

    //PUBLIC FUNCTIONS

    // method called by participants who want to purchase a ticket in the purchasing period
    function purchaseTicket() payable public inTime{
        //only 1 ether is accepted (maybe it's unrealistic but it has been chosen for simplicity)
        require(msg.value == 1 ether, "Wrong price for a ticket (1 ether)");
        //we add the ether to the prize pool and introduce the participant to the ledger
        balance += msg.value;
        ticketLedger[lotteryNum][soldTickets] = msg.sender;
        soldTickets++;
    }

    //can only be called by the owner of the lottery, when the prize hasn't already
    //been collected and when the timer is over.
    function selectWinner() payable public isOwner notClaimed timerOver{
        //choose a winner from the ledger and get his address
        winnerLedger[lotteryNum] = ticketLedger[lotteryNum][randomIntInLedger()];
        //change global state of the sc to prize claimed
        claimed = true;
        //transfer the prize to the winner's address
        payable(winnerLedger[lotteryNum]).transfer(balance);
    }

    //can only be called by the owner when the prize of the previous lottery has 
    //already been collected.
    //reset the clock by setting a new timer of _seconds, reset other necessary
    //variables
    function resetLottery(uint256 _seconds) public isOwner isClaimed {
        balance = 0;
        deadline = block.timestamp + _seconds;
        claimed = false;
        soldTickets = 0;
        lotteryNum++;
    }

    //PRIVATE FUNCTIONS

    //blockchain is a deterministic system, which means that it can not generate
    //true randomness. So either off-chain or pseudo-randomness have to be used
    //to choose a winner.
    //To achive pseudo-randomness we used a hash algorithm (keccak256) combining
    //multiple indicators. 
    //block.timestamp:  time at which we call the function
    //block.difficulty: current difficulty of the blockchain.
    //msg.sender: address of the sender of the transaction.
    //We combine all of these with the “abi.encodePacked” library and transform 
    //the hash into bytes.
    //keccak256: computes the hash of the input and takes the byte value as an argument.
    //We use a mod (%) operator to choose equally the identifier of all participants.
    function randomIntInLedger() private view returns (uint256){
        return uint256(keccak256(abi.encodePacked(block.timestamp,block.difficulty,msg.sender))) % soldTickets;
    }

    //TESTING PROCEDURE IN REMIX

    // 1. owner deploys the contract introducing the number of seconds of the purchasing 
    //    period.
    // 2. participants call the purchaseTicket method and introduce 1 ether as msg.value
    // 3. once the clock is over the owner calls selectWinner and the prize will be sent
    //    to the winner
    // 4. once the prize has been collected the owner calls resetLottery with the new time
    //    as an attribute. This creates a new lottery scheme and we go back to step 2.
}
