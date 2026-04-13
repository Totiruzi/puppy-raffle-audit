### [S-#] Looping through the players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential Denial Of Service (DoS) attack, increasing gas cost for future entrants.

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