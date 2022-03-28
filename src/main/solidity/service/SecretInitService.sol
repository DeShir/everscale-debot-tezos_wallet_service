pragma ton-solidity >= 0.53.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

import "https://raw.githubusercontent.com/DeShir/everscale-service/8472e40e339e66af81b594d6b66082df8c425c01/src/main/solidity/debot/tezos/ITezosAccountService.sol";
import "https://raw.githubusercontent.com/tonlabs/debots/49eb9ea211c7146ba00895bcbe05b5e76d3c720c/Debot.sol";
import "../interface/_all.sol";

contract SecretInitService is Debot, ITezosAccountServiceMenuItem, ITezosAccountServiceRun {

    optional(address) private hostAddr;

    /// @notice Entry point function for DeBot.
    function start() public override {
        hostAddr = msg.sender;
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns (
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Secret Init Service";
        version = "0.1.0";
        publisher = "ShiroKovka(Oba!=)";
        caption = "";
        author = "ShiroKovka";
        support = address.makeAddrStd(0, 0xfe9a76f1a8584fbd8f092b20e917918969fc8a7b1759e9a8c15a7f907e4d72a5);
        hello = "Hello";
        language = "en";
        dabi = m_debotAbi.get();
        icon = "";
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [SigningBoxInput.ID];
    }

    function menuItem(TezosLibrary.Account request) override external responsible returns(MenuItem) {
        return ITezosAccountServiceMenuItem.MenuItem("Input Secret", "");
    }

    function run(TezosLibrary.Account request) override external {
        hostAddr = msg.sender;
        SigningBoxInput.get(tvm.functionId(requestSecretCallback), "Input Secret", new uint256[](0));
    }

    function requestSecretCallback(uint32 handle) public {
        if(hostAddr.hasValue()) {
            ITezosAccountServiceCallback(hostAddr.get()).update(TezosLibrary.Account(null, handle));
            ITezosAccountServiceCallback(hostAddr.get()).finish();
        }
    }
}
