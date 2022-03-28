pragma ton-solidity >= 0.53.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

import "https://raw.githubusercontent.com/DeShir/everscale-service/8472e40e339e66af81b594d6b66082df8c425c01/src/main/solidity/debot/tezos/ITezosAccountService.sol";
import "https://raw.githubusercontent.com/tonlabs/debots/49eb9ea211c7146ba00895bcbe05b5e76d3c720c/Debot.sol";
import "../interface/_all.sol";
import "../lib/_all.sol";

contract ShowBalanceService is Debot, ITezosAccountServiceMenuItem, ITezosAccountServiceRun {

    using TezosJSON for JsonLib.Value;
    using Net for *;
    using TezosUnits for int;

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
        name = "Show Balance Service";
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
        return [Network.ID, Terminal.ID];
    }

    function menuItem(TezosLibrary.Account request) override external responsible returns(MenuItem) {
        return ITezosAccountServiceMenuItem.MenuItem("Check Balance", "");
    }

    function run(TezosLibrary.Account request) override external {
        hostAddr = msg.sender;
        if(request.addr.hasValue()) {
            string url = Net.tezosUrl("/chains/main/blocks/head/context/contracts/" + request.addr.get());
            url.get(tvm.functionId(requestBalanceCallback));
        } else {
            Terminal.print(0, "Tezos Wallet address isn't initialized.");
        }
    }

    function requestBalanceCallback(int32 statusCode, string[] retHeaders, string content) public {
        require(statusCode == 200, 101);
        Json.parse(tvm.functionId(parseBalanceCallback), content);
    }

    function parseBalanceCallback(bool result, JsonLib.Value obj) public {
        optional(int) balance = obj.balance();
        if(balance.hasValue()) {
            Terminal.print(0, format("Balance: {}xtz", balance.get().xtz()));
        } else {
            Terminal.print(0, "Balance didn't available.");
        }
        if(hostAddr.hasValue()) {
            ITezosAccountServiceCallback(hostAddr.get()).finish();
        }
    }
}
