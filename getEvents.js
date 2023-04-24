
const ABIproxy = require('./ABIproxy');
var Web3 = require('web3');
var provider = 'https://data-seed-prebsc-1-s3.binance.org:8545';
var web3Provider = new Web3.providers.HttpProvider(provider);
var web3 = new Web3(web3Provider);


const CONTRACT_ADDRESS = '0x006d88AB1E9Edc75B78bd93fd76aB0A75CA770E4';

const myContract = new web3.eth.Contract(ABIproxy,CONTRACT_ADDRESS);
console.log(myContract);
web3.eth.getBlockNumber().then((result) => {
  console.log("Latest Ethereum Block is ",result);
});
async function getSwapSignature() {
        const addres = await myContract.getMessageHash('tx1','0xCc48C437020B17D881C719Ff53DF4e56022Fb61A','100000000000000000000');
        console.log(addres);

 
  }

getSwapSignature();
