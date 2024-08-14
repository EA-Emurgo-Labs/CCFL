# CCFL

npx hardhat compile
npx hardhat test
npx hardhat coverage
npx hardhat ignition deploy ignition/modules/CCFLPool.ts --network sepolia
npx hardhat verify 0x85B85Aa3dAcdE3bcc1EDbFf6701aA0541162Abef --network sepolia

remixd -s ./contracts -u https://remix.ethereum.org/