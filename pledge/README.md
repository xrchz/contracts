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

## Actions

### create
`create((bytes32 poolId, uint256 deadline, address buyToken, uint256 minBuy, address sellToken, uint256 maxSellForMin), uint256 buyTokenIndex, uint256 sellTokenIndex) → uint256 id`

Create a new pledging agreement for people to participate in.

#### Arguments
- `poolId`: the identifier for the Balancer pool in which to execute the swap.
- `deadline`: the Unix time (in seconds) after which the pledging agreement expires.
- `buyToken`: the ERC20 token we are pledging to buy.
- `minBuy`: the target minimum amount of `buyToken` to buy.
- `sellToken`: the ERC20 token we are selling in order to buy `buyToken`.
- `maxSellForMin`: the maximum amount of `sellToken` to sell for each `minBuy` portion of `buyToken`. In other words, the maximum price at which to buy `buyToken` is `maxSellForMin ÷ minBuy`.
- `buyTokenIndex`: the token index of `buyToken` in the `poolId` pool's tokens (as returned by `getPoolTokens(poolId)` on the Balancer vault).
- `sellTokenIndex`: the token index of `sellToken` in the `poolId` pool's tokens.

#### Returns
- `id`: the identifier for the pledging agreement, used to refer to this agreement in future calls.

#### Emits
- `Create(uint256 indexed id, address indexed buyToken, address indexed sellToken, uint256 minBuy, uint256 maxSellForMin, uint256 deadline)`

#### Errors
- `"deadline"`: if the `deadline` is in the past (before `block.timestamp`).
- `"minBuy"`: if the `minBuy` is zero.
- `"buyToken"`: if the `buyToken` does not correspond to the `buyTokenIndex` token in the `poolId` pool.
- `"sellToken"`: if the `sellToken` does not correspond to the `sellTokenIndex` token in the `poolId` pool.

### pledge
`pledge(uint256 id, uint256 amount)`

Commit `amount` of `sellToken` to the pledging agreement `id`.

### execute
`execute(uint256 id) → uint256 amountBought`

Execute the trade of `sellToken` for `buyToken` represented by the pledging agreement `id`.

### claim
`claim(uint256 id) → uint256 amountBought`

Claim the portion of the `buyToken` tokens obtained via a successfully executed pledging agreement `id` owed to the caller.

### dust
`dust(uint256 id) → uint256 amountDusted`

Claim any remaining `buyToken` tokens left over due to rounding errors after all claims have been made on the pledging agreement `id`.

### refund
`refund(uint256 id) → uint256 amountRefunded`

Return the `sellToken` tokens committed by the caller to an expired pledging agreement `id`.

## Views

### vault
`vault() → address`

View the `address` of the Balancer vault being used.

### pledges
`pledges(uint256 id) → (bytes32 poolId, uint256 deadline, address buyToken, uint256 minBuy, address sellToken, uint256 maxSellForMin)`

View details of the pledging agreement `id`.

### numPledges
`numPledges() → uint256`

View the number of pledging agreements that have been created.
This value will be the `id` of the next agreement to be created.

### totalPledged
`totalPledged(uint256 id) → uint256`

View the total amount of `sellToken` ever committed to the pledging agreement `id`, including amounts subsequently refunded or sold.

### totalBought
`totalBought(uint256 id) → uint256`

### totalClaimed
`totalClaimed(uint256 id) → uint256`

### activePledgers
`activePledgers(uint256 id) → uint256`

### pledged
`pledged(uint256 id, address user) → uint256`
