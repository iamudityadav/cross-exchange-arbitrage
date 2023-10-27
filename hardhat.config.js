require("@nomiclabs/hardhat-waffle");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      { version: "0.5.0" },
      { version: "0.6.2" },
      { version: "0.8.9" },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://ethereum.publicnode.com"
      },
    },
  },
};