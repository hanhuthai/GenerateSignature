var Web3 = require('web3');
var provider = 'https://data-seed-prebsc-1-s3.binance.org:8545';
var web3Provider = new Web3.providers.HttpProvider(provider);
var web3 = new Web3(web3Provider);
web3.eth.getBlockNumber().then((result) => {
  console.log("Latest Ethereum Block is ",result);
});
async function getSwapSignature() {
    //hard from getMessageHash method
    const hash = '0xeee2b54e76f7a0251915e948ff9f60c214a2e1fb89265890bcea6e125c8d40e4';
    const privateKeyOfSigner ='';
    const signature = await web3.eth.accounts.sign(hash, privateKeyOfSigner);
    console.log(signature);
    return signature;
  }

getSwapSignature();
