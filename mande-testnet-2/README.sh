#!/bin/bash

# Setting up vars
echo "*********************"
echo -e "\e[1m\e[35m		Lets's begin\e[0m"
echo "*********************"
echo -e "\e[1m\e[32m	Enter your Node Name:\e[0m"
echo "_|-_|-_|-_|-_|-_|-_|"
read NODENAME
echo "_|-_|-_|-_|-_|-_|-_|"
echo export NODENAME=${Nodename} >> $HOME/.bash_profile
echo export CHAIN_ID="mande-testnet-1" >> $HOME/.bash_profile
source ~/.bash_profile

# Save variables to system
echo "export NODENAME=$NODENAME" >> $HOME/.bash_profile
if [ ! $WALLET ]; then
    echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export MANDE_CHAIN_ID=mande-testnet-2" >> $HOME/.bash_profile
source $HOME/.bash_profile

# Update packages
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install curl build-essential git wget jq make gcc tmux net-tools -y

# Install go
ver="1.19" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \
go version

# Download and build binaries
cd $HOME
wget https://snapshot3.konsortech.xyz/mande/mande-chaind.tar.gz
tar -xzvf mande-chaind.tar.gz && chmod +x mande-chaind
mv mande-chaind /usr/local/go/bin/

# Install Wasm Library
cd $HOME
wget https://snapshot3.konsortech.xyz/mande/libwasmvm.x86_64.so
chmod +x libwasmvm.x86_64.so
mv libwasmvm.x86_64.so /usr/lib/

# Init app
mande-chaind init $NODENAME --chain-id $MANDE_CHAIN_ID

# Download configuration
wget -O $HOME/.mande-chain/config/genesis.json "https://raw.githubusercontent.com/mande-labs/testnet-2/main/genesis.json"

# Set minimum gas price, seeds, and peers
sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.005mand\"/;" ~/.mande-chain/config/app.toml
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $HOME/.mande-chain/config/config.toml
peers="dbd1f5b01f010b9e6ae6d9f293d2743b03482db5@34.171.132.212:26656,1d1da5742bdd281f0829124ec60033f374e9ddac@34.170.16.69:26656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.mande-chain/config/config.toml
seeds="cd3e4f5b7f5680bbd86a96b38bc122aa46668399@34.171.132.212:26656"
sed -i.bak -e "s/^seeds =.*/seeds = \"$seeds\"/" $HOME/.mande-chain/config/config.toml

# Disable indexing
indexer="null" && \
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.mande-chain/config/config.toml

# Update ~/.mande-chain/config/config.toml
cat << EOF >> $HOME/.mande-chain/config/config.toml
send_rate = 20000000
recv_rate = 20000000
max_packet_msg_payload_size = 10240
flush_throttle_timeout = "50ms"
mempool.size = 10000
create_empty_blocks = false
EOF

# Config pruning
pruning="custom" && \
pruning_keep_recent="100" && \
pruning_keep_every="0" && \
pruning_interval="10" && \
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" ~/.mande-chain/config/app.toml && \
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" ~/.mande-chain/config/app.toml && \
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" ~/.mande-chain/config/app.toml && \
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" ~/.mande-chain/config/app.toml

# Create service
sudo tee /etc/systemd/system/mande-chaind.service > /dev/null <<EOF
[Unit]
Description=mande-chaind
After=network-online.target

[Service]
User=$USER
ExecStart=$(which mande-chaind) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Register and start service
sudo systemctl daemon-reload
sudo systemctl enable mande-chaind
sudo systemctl restart mande-chaind

#SNAPSHOT
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


