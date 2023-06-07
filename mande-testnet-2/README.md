# MANDE

<p style="font-size:2px" align="center">
<button style="width:90px" href="https://crxa.my.id" target="_blank">Visit Website</button>
</p>

## Minimum Requirements

- 2 or more physical CPU cores
- At least 100GB of SSD disk storage
- At least 4GB of memory (RAM)
- At least 100mbps network bandwidth

# Auto Install

```
wget -O mande.sh https://raw.githubusercontent.com/caraka15/testnet-guide/master/mande-testnet-2/mande.sh && chmod +x mande.sh && ./mande.sh
```

#SNAPSHOT

```
sudo systemctl stop mande-chaind

cp $HOME/.mande-chain/data/priv_validator_state.json $HOME/.mande-chain/priv_validator_state.json.backup
mande-chaind tendermint unsafe-reset-all --home $HOME/.mande-chain --keep-addr-book

SNAP_RPC="https://testnet-mande-rpc.konsortech.xyz:443"

LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height); \
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000)); \
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

echo $LATEST_HEIGHT $BLOCK_HEIGHT $TRUST_HASH

peers="f011505f4eb1490bba56719dda171934b2ca0c9f@testnet-mande.konsortech.xyz:12656"
sed -i 's|^persistent_peers *=.*|persistent_peers = "'$peers'"|' $HOME/.mande-chain/config/config.toml

sed -i -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \
s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC,$SNAP_RPC\"| ; \
s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \
s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|" $HOME/.mande-chain/config/config.toml

mv $HOME/.mande-chain/priv_validator_state.json.backup $HOME/.mande-chain/data/priv_validator_state.json

sudo systemctl restart mande-chaind
sudo journalctl -u mande-chaind -f --no-hostname -o cat
```

## Usefull commands

### Service management

Check logs

```
journalctl -fu mande-chaind -o cat
```

Start service

```
sudo systemctl start mande-chaind
```

Stop service

```
sudo systemctl stop mande-chaind
```

Restart service

```
sudo systemctl restart mande-chaind
```

### Node info

Synchronization info

```
mande-chaind status 2>&1 | jq .SyncInfo
```

Validator info

```
mande-chaind status 2>&1 | jq .ValidatorInfo
```

Node info

```
mande-chaind status 2>&1 | jq .NodeInfo
```

Show node id

```
mande-chaind tendermint show-node-id
```

### Wallet operations

List of wallets

```
mande-chaind keys list
```

Recover wallet

```
mande-chaind keys add <wallet> --recover
```

Delete wallet

```
mande-chaind keys delete <wallet>
```

Get wallet balance

```
mande-chaind query bank balances <address>
```

Transfer funds

```
mande-chaind tx bank send <FROM ADDRESS> <TO_MANDE_WALLET_ADDRESS> 10000000mand
```

### Voting

```
mande-chaind tx gov vote 1 yes --from <wallet> --chain-id=mande-testnet-1
```

### Staking, Delegation and Rewards

Delegate stake

```
mande-chaind tx staking delegate <mande valoper> 10000000mand --from=<wallet> --chain-id=mande-testnet-1 --gas=auto
```

Redelegate stake from validator to another validator

```
mande-chaind tx staking redelegate <srcValidatorAddress> <destValidatorAddress> 10000000mand --from=<wallet> --chain-id=mande-testnet-1 --gas=auto
```

Withdraw all rewards

```
mande-chaind tx distribution withdraw-all-rewards --from=<wallet> --chain-id=mande-testnet-1 --gas=auto
```

Withdraw rewards with commision

```
mande-chaind tx distribution withdraw-rewards <mande valoper> --from=<wallet> --commission --chain-id=mande-testnet-1
```

### Validator management

Edit validator

```
mande-chaind tx staking edit-validator \
  --moniker=<moniker> \
  --identity=<your_keybase_id> \
  --website="<your_website>" \
  --details="<your_validator_description>" \
  --chain-id=mande-testnet-1 \
  --from=<wallet>
```

Unjail validator

```
mande-chaind tx slashing unjail \
  --broadcast-mode=block \
  --from=<wallet> \
  --chain-id=mande-testnet-1 \
  --gas=auto
```

### Delete node

```
sudo systemctl stop mande-chaind && \
sudo systemctl disable mande-chaind && \
rm /etc/systemd/system/mande-chaind.service && \
sudo systemctl daemon-reload && \
cd $HOME && \
rm -rf .mande-chain && \
rm -rf $(which mande-chaind)
```
