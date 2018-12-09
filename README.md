# Bitcoin:

Implement the functionaliy of Bitcoin: A Peer-to-Peer Electronic Cash System using Blockchain. There is no centralised auhority, anybody can make transactioons and anybody can verify transactions

#Group Information:

Name: Ashwin Kalyana Kumar, UFID: 13517733
Name: Jinansh Rupesh Patel, UFID: 94318155 

## Installation:

There is no need for installation

To run the tests for the project just type mix test test/bitcoin_test.exs

The final test case takes about 5 minutes to complete where the entire bitcoin algorithm is implemented and the nodes are mining bitcoins and transacting them.

## Implementation:

The entire bitcoin functionality is implemented. 

Each node has a wallet with its own private and public key
Each node is able to create a transaction. Each node is able to verify any transaction.
Each node is able to generate a block in the block chain by verifying the transaction. This block is validated and propogated throughout the network.
Every node's wallet has a balance and a list of spendable transactions, with which new transactions are created. 

Each node is able to communicate with other nodes, by sending and receiving transactions and blocks.

Each node is able to maintain a blockchain, and the branch conflicts are removed after 5 blocks are generated after the conflict.

Each node maintains a lists of unverified transaction, which it received and tries to create a block out of it. When someone generates a block and sends it to this particular node, 
he then removes the transactions verified in that block and tries to generate a new block with the remining transactions.

Each node, get bitcoins as  when they successfully mine a block. 
Inorder to successfully mine a block each node should be able to generate a hash for the block starting with 20 zeros (5 zeros in hexadecimal)
Any transaction cant be used as an input for another transaction, before 10 blocks have passed. 
The coinbase transaction reward cannot be used for another 100 blocks.

No node further propogates an invalid block or an invalid transaction. 

The nodes are arranged in an imperfect loop, where each node has 3 neighbors, left, right and a random node.

A node, when joining the network can decide whether he wants to mine bitcoins or not. Any non-miner can become a miner or vice versa at any point of time.

The nodes can be added to and removed from the network dynamically. 

## Tests:

    # test "public and private key generation"

    This is testing the generation of public and private keys for a node 
    We are just checking whether we have a binary public and private key

    # test "digitally sign and verify"

    This is testing the digital signature that we will be using in the transaction of bitcoin.
    Over here we are first generating the public nad private key, Checking whether this keys are binary then we are creating a signature using the private key and then we are verifying the same signature using the public key

    # test "create and verify transaction"

    This is testing the authenticity of a transaction once a transaction is generated
    Over here we are first creating two public and private key pairs for a transaction to happen between them. Then we are creating hash for both the public keys. Then we are creating a coinbase transaction with 50 bitcoin. We are sending 20 bitcoins from one node to other and it will send 30 transaction back to itself. And then we are checking the authenticity of this transaction

    # test "create and verify block"

    This is testing the generation of a block
    Over here we are first creating public and private key pairs for a node. Then we are creating hash for the public keys. And then we are generating a block using a coinbase transaction and validating that block.

    # test "create and verify block with transaction"

    This is testing is testing the creation of block with a transaction between two node inlcuding the bitcoin transaction
    OOver here we are first creating two public and private key pairs for a transaction to happen between them. Then we are creating hash for both the public keys. Then we are creating a coinbase transaction with 50 bitcoin. We are sending 20 bitcoins from one node to other and it will send 30 transaction back to itself. And then we are checking the authenticity of this transaction. Then we are generating a block using that transaction and validating that block

    # test case "entire thing"

    In this test case, we are testing the entire functionality. 
    15 miners are added to the network, and everybody is trying to generate a new block and add it to the block chain. 
    The block reward is set at 50 BTC per block.
    The complexity is set at 20 zeros initially (5 zeros in hexadecimal) to a block.
    These nodes mine bitcoin by generating blocks with only one transaction - the coinbase transaction. 
    the coinbase transaction cant be spent for the next 100 blocks. So these 15 nodes are allowed to just mine blocks without any transactions, for 200 seconds. 

    After this, a new node is added to the network, who is a non miner. This new node requests bitcoins from the miners at random. every 10 seconds.
    The wallets are checked later, and also it is checked if the transactions are added to the blocks and verified.

    Apart from this, the transactions and blocks are verified internally, without which the nodes will reject the transactions/blocks

## Bonus

features included.

Each node has a wallet with a public and private key with which they can make transactions.
Each node can create transactions - Send and receive bitcoins
Each node can mine bitcoins.
Each node can verify a transaction / block
Each node can maintain a blockchain
Each node handles branching in the blockchain gracefully.
The branches in the chain gets removed after 5 blocks have been generated and the branch has not been developed upon.
Each node can spend the money they got from a transaction, 10 blocks after the block in which they received the transaction.
Each node can spend the reward(coinbase transaction) 100 bocks after the block in which they received the transaction. 
If a node receives an authentic transaction, but the 10 or 100 block condition hasnt been satisfied, then the node does not reject the transaction outright, it waits until the 10/100 block condition is satisfied, then tries to verify the transaction. If that fails, then it rejects the transaction.
The key generation algorithm used here is ECDH, the digital signature is done using ECDSA with the named curve "brainpoolP512r1" and the hashing algorithm used here is SHA-512.



