# Pledge Buy Contract

Trustless permissionless smart contract for making a trade (on Balancer) as a group!

Specify:
- Which token you want to buy
- Which token you want to sell
- The target minimum amount of the buy token to buy
- An acceptable price threshold (maximum amount of sell token to sell per target amount of buy token bought)
- A deadline

The contract then accepts commitments to buy the buy token using the sell token.
If the target is reached by the deadline, the trade can be executed.
Then everyone who participated can claim their portion of the bought buy token.
If the target is not reached by the deadline, everyone who committed sell token can refund their commitment.

## Cool features

- Immutable permissionless design: no admins, no upgrades, anyone can play
- Contract does not hold any funds (they are sent straight to the Balancer Vault internal balance)
- Works with any ERC20s (for which a Balancer pool exists for doing the trade)
- Written in fewer than 256 lines of Vyper for security and readability

# Smart Contract Interface

## create
`create((bytes32 poolId, uint256 deadline, address buyToken, uint256 minBuy, address sellToken, uint256 maxSellForMin), uint256 buyTokenIndex, uint256 sellTokenIndex) → uint256 id`

## pledge
`pledge(uint256 id, uint256 amount)`

## execute
`execute(uint256 id) → uint256 amountBought`

## claim
`claim(uint256 id) → uint256 amountBought`

## dust
`dust(uint256 id) → uint256 amountDusted`

## refund
`refund(uint256 id) → uint256 amountRefunded`
