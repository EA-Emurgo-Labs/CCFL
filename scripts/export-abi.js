const FileSystem = require("fs");

const CONTRACT_FOLDER = "../artifacts/contracts";
const OUTPUT_FOLDER = "./abis";
/**
 *
 * @param {string} contract
 * @param {string} OUTPUT_FOLDER
 */
const exportAbi = function (contract) {
  const artifact = require(`${CONTRACT_FOLDER}/${contract}.sol/${contract}.json`);
  console.log("Contract name: ", artifact.contractName);
  const abiPath = OUTPUT_FOLDER + "/" + artifact.contractName + ".json";
  console.log("\tWriting ABI file: ", abiPath);
  FileSystem.writeFileSync(abiPath, JSON.stringify(artifact.abi, null, "  "));
};
/**
 *
 * @param {string[]} contracts
 * @param {string} OUTPUT_FOLDER
 */
const exportAbis = function (contracts) {
  contracts.forEach((contract) => exportAbi(contract));
};

exportAbis([
  "CCFLPool",
  "CCFL",
]);
