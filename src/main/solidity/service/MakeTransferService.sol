pragma ton-solidity >= 0.53.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

import "https://raw.githubusercontent.com/DeShir/everscale-service/8472e40e339e66af81b594d6b66082df8c425c01/src/main/solidity/debot/tezos/ITezosAccountService.sol";
import "https://raw.githubusercontent.com/tonlabs/debots/49eb9ea211c7146ba00895bcbe05b5e76d3c720c/Debot.sol";
import "../interface/_all.sol";
import "../lib/_all.sol";

contract MakeTransferService is Debot, ITezosAccountServiceMenuItem, ITezosAccountServiceRun {

    optional(address) private hostAddr;

    using TezosJSON for JsonLib.Value;
    using JsonLib for JsonLib.Value;
    using Net for string;
    using TezosUnits for int;

    TezosLibrary.Account private account;

    string private branch;
    string private destination;
    int private amount;
    int private fee;
    int256 private counter;

    int private countTezosInformationRequests;
    string private forgeTransactionData;

    /// @notice Entry point function for DeBot.
    function start() public override {
        hostAddr = msg.sender;
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns (
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Make Transfer Service";
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
        return [Network.ID, Sdk.ID, SigningBoxInput.ID, Hex.ID];
    }

    function menuItem(TezosLibrary.Account request) override external responsible returns(MenuItem) {
        return ITezosAccountServiceMenuItem.MenuItem("Make transfer", "");
    }

    function run(TezosLibrary.Account request) override external {
        hostAddr = msg.sender;
        if(!request.addr.hasValue() || !request.signBoxHandle.hasValue()) {
            Terminal.print(0, "Tezos wallet address or sign box are not initialized.");
        }
        account = request;
        Terminal.input(tvm.functionId(requestDestinationAddressCallback), "Please input  target Tezos Wallet Address:", false);
    }

    function requestDestinationAddressCallback(string value) public {
        destination = value;
        AmountInput.get(tvm.functionId(requestTransferAmountCallback), "Enter amount:",  6, 0, 1000e6);
    }

    function requestTransferAmountCallback(uint128 value) public {
        amount = value;
        AmountInput.get(tvm.functionId(requestTransferFeeCallback), "Enter fee:",  6, 0, 1000e6);
    }

    function requestTransferFeeCallback(uint128 value) public {
        fee = value;
        countTezosInformationRequests = 2;
        string url;
        url = Net.tezosUrl("/chains/main/blocks/head/header");
        url.get(tvm.functionId(requestHeaderCallback));
        url = Net.tezosUrl("/chains/main/blocks/head/context/contracts/" + account.addr.get());
        url.get(tvm.functionId(requestContractCallback));
    }

    function requestHeaderCallback(int32 statusCode, string[] retHeaders, string content) public {
        Json.parse(tvm.functionId(parseHeaderCallback), content);
    }

    function requestContractCallback(int32 statusCode, string[] retHeaders, string content) public {
        Json.parse(tvm.functionId(parseCounterCallback), content);
    }

    function parseHeaderCallback(bool result, JsonLib.Value obj) public {
        branch = obj.hash().get();
        countTezosInformationRequests -= 1;
        isRequestedDataCompleted();
    }

    function parseCounterCallback(bool result, JsonLib.Value obj) public {
        counter = obj.counter().get();
        countTezosInformationRequests -= 1;
        isRequestedDataCompleted();
    }

    function isRequestedDataCompleted() private {
        if(countTezosInformationRequests == 0) {
            requestTransactionForge();
        }
    }

    function requestTransactionForge() private {
        string url = Net.tezosUrl("/chains/main/blocks/head/helpers/forge/operations");
        url.post(tvm.functionId(requestTransactionForgeCallback),
        TezosJSON.forgeTransactionRequest(branch, account.addr.get(), destination, amount, fee, counter + 1));
    }

    function requestTransactionForgeCallback(int32 statusCode, string[] retHeaders, string content) public {
        Json.parse(tvm.functionId(parseTransactionForgeCallback), content);
    }

    function parseTransactionForgeCallback(bool result, JsonLib.Value obj) public {
        if(obj.as_string().hasValue()) {
            forgeTransactionData = obj.as_string().get();
            ConfirmInput.get(tvm.functionId(confirmTransactionCallback),
            format("Confirm transaction. Transfer {} xtz, (fee = {} xtz) from {}, to {}",
            amount.xtz(), fee.xtz(),
            account.addr.get(), destination));
        } else {
            ITezosAccountServiceCallback(hostAddr.get()).finish();
        }
    }

    function confirmTransactionCallback(bool value) public {
        if(value) {
            string url = Net.helperUrl("/hash/blake/" + "03" + forgeTransactionData);
            url.get(tvm.functionId(blakeTransactionCallback));
        } else {
            ITezosAccountServiceCallback(hostAddr.get()).finish();
        }
    }

    function blakeTransactionCallback(int32 statusCode, string[] retHeaders, string content) public {
        Sdk.signHash(tvm.functionId(signTransactionCallback), account.signBoxHandle.get(), uint256(stoi("0x" + content).get()));
    }

    function signTransactionCallback(bytes signature) public {
        Hex.encode(tvm.functionId(injectTransaction), signature);
    }

    function injectTransaction(string hexstr) public {
        string url = Net.tezosUrl("/injection/operation");
        url.post(tvm.functionId(injectTransactionCallback), "\"" + forgeTransactionData + hexstr + "\"");
    }

    function injectTransactionCallback(int32 statusCode, string[] retHeaders, string content) public {
        ITezosAccountServiceCallback(hostAddr.get()).finish();
    }
}
