pragma solidity 0.6.12;

// https://github.com/makerdao/osm
interface IOSM {
    function wards(address) external view returns (uint256);
    function stopped() external view returns (uint256);
    function src() external view returns (address);
    function hop() external view returns (uint16);
    function zzz() external view returns (uint64);
    function cur() external view returns (uint128, uint128);
    function nxt() external view returns (uint128, uint128);
    function bud(address) external view returns (uint256);
    function stop() external;
    function start() external;
    function change(address) external;
    function step(uint16) external;
    function void() external;
    function pass() external view returns (bool);
    function poke() external;
    function peek() external view returns (bytes32, bool);
    function peep() external view returns (bytes32, bool);
    function read() external view returns (bytes32);
    function kiss(address) external;
    function diss(address) external;
    function kiss(address[] calldata) external;
    function diss(address[] calldata) external;
}

contract LibNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  usr,
        bytes32  indexed  arg1,
        bytes32  indexed  arg2,
        bytes             data
    ) anonymous;

    modifier note {
        _;
        assembly {
            // log an 'anonymous' event with a constant 6 words of calldata
            // and four indexed topics: selector, caller, arg1 and arg2
            let mark := msize()                       // end of memory ensures zero
            mstore(0x40, add(mark, 288))              // update free memory pointer
            mstore(mark, 0x20)                        // bytes type data offset
            mstore(add(mark, 0x20), 224)              // bytes size (padded)
            calldatacopy(add(mark, 0x40), 0, 224)     // bytes payload
            log4(mark, 288,                           // calldata
                 shl(224, shr(224, calldataload(0))), // msg.sig
                 caller(),                            // msg.sender
                 calldataload(4),                     // arg1
                 calldataload(36)                     // arg2
                )
        }
    }
}

// Surrogate Lightweight OSM
contract SLOSM is LibNote {

    // --- Auth ---
    function wards(address usr) external returns (uint256) { return osm.wards(usr); }
    function rely(address) external { revert("SLOSM/rely-on-osm"); }
    function deny(address) external { revert("SLOSM/deny-on-osm"); }
    modifier auth {
        require(osm.wards(msg.sender) == 1, "SLOSM/not-authorized-on-osm");
        _;
    }

    // --- Stop ---
    function stop() external auth { _stopped = 1; }
    function start() external auth { _stopped = 0; }
    modifier stoppable {
        require(osm.stopped() == 0 && _stopped == 0, "SLOSM/is-stopped");
        _;
    }

    // --- Toll ---
    function kiss(address) external { revert("SLOSM/kiss-on-osm"); }
    function diss(address) external { revert("SLOSM/diss-on-osm"); }
    function kiss(address[] calldata) external { revert("SLOSM/kiss-on-osm"); }
    function diss(address[] calldata) external { revert("SLOSM/diss-on-osm"); }
    modifier toll {
        require(osm.bud(msg.sender) == 1, "SLOSM/contract-not-whitelisted-on-osm");
        _;
    }

    function change(address) external { revert("SLOSM/change-on-osm"); }

    event File(bytes32 indexed what, uint256 indexed data);
    event LogValue(bytes32 val);

    // --- Math ---
    function add(uint64 x, uint64 y) internal pure returns (uint64 z) {
        z = x + y;
        require(z >= x);
    }

    IOSM    public immutable osm;

    uint16 public hop;
    uint64 public zzz;

    uint256 internal _stopped;

    struct Feed {
        uint128 val;
        uint128 has;
    }

    Feed internal cur;
    Feed internal nxt;

    constructor(address _osm, uint256 _hop) public {
        require(_hop < uint16(-1), "SLOSM/invalid-hop");
        osm = IOSM(_osm);
        hop = uint16(_hop);
    }

    function file(bytes32 what, uint256 data) external auth {
        if (what == "hop") {
            require(data < uint16(-1), "SLOSM/hop-too-large");
            hop = uint16(data);
        }
        else revert("SLOSM/file-unrecognized-param");
        emit File(what, data);
    }

    function stopped() external view returns (uint256) {
        if (osm.stopped() == 1 || _stopped == 1) { return 1; }
    }

    function src() external view returns (address) {
        return osm.src();
    }

    function bud(address _usr) external view returns (uint256) {
        return osm.bud(_usr);
    }

    function prev(uint256 ts) internal view returns (uint64) {
        require(hop != 0, "SLOSM/hop-is-zero");
        return uint64(ts - (ts % hop));
    }

    function step(uint16 ts) external auth {
        require(ts > 0, "SLOSM/ts-is-zero");
        hop = ts;
    }

    function void() external note auth {
        cur = nxt = Feed(0, 0);
        _stopped = 1;
    }

    function pass() external view returns (bool) {
        return block.timestamp >= add(zzz, hop);
    }

    function poke() external stoppable note {
        require(block.timestamp >= add(zzz, hop), "SLOSM/not-passed");
        (bytes32 wut, bool ok) = osm.peek();
        if (ok) {
            cur = nxt;
            nxt = Feed(uint128(uint256(wut)), 1);
            zzz = prev(block.timestamp);
            emit LogValue(bytes32(uint256(cur.val)));
        }
    }

    function peek() external view toll returns (bytes32 val, bool has) {
        return (bytes32(uint(cur.val)), cur.has == 1);
    }

    function peep() external view toll returns (bytes32 val, bool has) {
        return (bytes32(uint(nxt.val)), nxt.has == 1);
    }

    function read() external view toll returns (bytes32) {
        return osm.read();
    }
}
