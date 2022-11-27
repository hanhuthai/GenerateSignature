const EthCrypto = require("eth-crypto");
const signerIdentity = EthCrypto.createIdentity();
const message = EthCrypto.hash.keccak256([
{type: "string",value: "Hello World!"}
]);
//const signature = EthCrypto.sign(signerIdentity.privateKey, message);
const signature = EthCrypto.sign('0xcbc8ab45c4e5862d8c1280a4d549a0a1312c4fbf4efc1794a3a76acc33defcb6', '0xa6ff4ecd805a72f8ac5de64989c7ce71577b5de8');
console.log(`message: ${message}`);
console.log(`signature: ${signature}`);
console.log(`signer public key: ${signerIdentity.address}`);