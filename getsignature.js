var Web3 = require('web3');
var provider = 'https://data-seed-prebsc-1-s3.binance.org:8545';
var web3Provider = new Web3.providers.HttpProvider(provider);
var web3 = new Web3(web3Provider);
require('dotenv').config();
web3.eth.getBlockNumber().then((result) => {
  console.log("Latest Ethereum Block is ",result);
});


async function getSwapSignature() {
    //hard from getMessageHash method
    const hash = '0xdc0b1f7a728e432451d4cc92f337b22e02b7bcb064dfca6ecea54f99d1f0d7b5';
    const privateKeyOfSigner ='';
    const signature = await web3.eth.accounts.sign(hash, process.env.PRIVATE_KEY);
    console.log(signature.signature);

    return signature;
  }

getSwapSignature();
