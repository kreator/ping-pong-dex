# Ping Pong Dex

Ping pong is a decentralized exchange architecture that:

- Enables instant trading via an automated market maker
- Enables people to place limit orders using a fixed price orderbook
- Uses that order book to create non reversible trading steps, making the exchange a frontrunning resistant pricing source

## Development & Testing

So if you don't already have the excellent truffle and ganache installed you should probably start by installing them [here](https://truffleframework.com).

Next clone this repo and install dependencies
```shell
git clone https://github.com/kreator/ping-pong-dex
cd ping-pong-dex
npm install
```

To run the tests you need to make sure that ganache is running and then:
```shell
truffle migrate --reset
truffle test
```
